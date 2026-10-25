#!/usr/bin/env bash
# =========================================================
# VPS 综合网络优化与节点一键部署脚本 (增强版)
# 包含: 环境修复 / BBR与UDP优化 / VLESS-Reality / Hysteria2 / WARP
# =========================================================

set -e

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

info() { echo -e "${GREEN}[INFO] $1${PLAIN}"; }
warn() { echo -e "${YELLOW}[WARN] $1${PLAIN}"; }
error() { echo -e "${RED}[ERROR] $1${PLAIN}"; }

# 检查是否以 root 运行
if [[ $EUID -ne 0 ]]; then
    error "必须使用 root 权限运行此脚本！"
    exit 1
fi

# 1. 修复语言包与基础环境
fix_environment() {
    info "正在安装基础依赖并配置 en_US.UTF-8 字符集..."
    if command -v apt-get &>/dev/null; then
        apt-get update -y
        apt-get install -y locales curl wget openssl ca-certificates perl
        locale-gen en_US.UTF-8
        update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
    elif command -v yum &>/dev/null; then
        yum install -y glibc-common curl wget openssl ca-certificates perl
    fi

    if perl -e exit 2>/dev/null; then
        info "Perl 及系统语言环境检测正常！"
    else
        warn "语言环境配置可能存在警告，但已尝试修正。"
    fi
}

# 2. 开启 BBR 及网络缓冲区优化（含 Hysteria 2 所需的 UDP 缓存）
enable_bbr_and_sysctl() {
    info "正在配置 BBR 拥塞控制及 UDP 网络缓冲区..."

    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
    sed -i '/net.core.wmem_max/d' /etc/sysctl.conf

    cat >> /etc/sysctl.conf << 'SYSCTL_EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
# 优化 UDP 接收/发送缓冲区（Hysteria 2 推荐配置，消除丢包与缓冲警告）
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
SYSCTL_EOF

    sysctl -p >/dev/null 2>&1

    info "BBR 与缓冲区配置已生效，当前拥塞控制算法："
    sysctl net.ipv4.tcp_available_congestion_control
    sysctl net.ipv4.tcp_congestion_control
}

# 3. 安装 VLESS Reality (调用 Mack-a 脚本)
install_vless_reality() {
    info "准备运行 Mack-a v2ray-agent 脚本安装 VLESS Reality..."
    warn "该脚本带有交互式菜单，请在弹出菜单中选择【个性化安装 -> 7 或 8（包含 Reality）】"
    read -rp "按回车键继续..." dummy

    wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" || \
    wget -P /root -N --no-check-certificate "https://www.v2ray-agent.com/v2ray-agent/install.sh"
    chmod 700 /root/install.sh
    /root/install.sh
}

# 端口输入与校验函数
get_valid_port() {
    local prompt_text="$1"
    local default_port="$2"
    local target_port

    while true; do
        read -rp "${prompt_text} [默认: ${default_port}，直接回车使用默认]: " target_port
        target_port=${target_port:-$default_port}

        # 检查是否为 1-65535 纯数字
        if [[ "$target_port" =~ ^[0-9]+$ ]] && [ "$target_port" -ge 1 ] && [ "$target_port" -le 65535 ]; then
            echo "$target_port"
            return 0
        else
            error "端口号无效！请输入 1 到 65535 之间的纯数字。"
        fi
    done
}

# 4. 安装与配置 Hysteria 2
install_hysteria2() {
    info "开始安装 Hysteria 2 官方服务..."
    bash <(curl -fsSL https://get.hy2.sh/)

    echo ""
    warn "提示: VLESS Reality 使用 TCP 443，Hysteria 2 使用 UDP 443，两者协议不同，可同时使用 443 端口。"
    hy2_port=$(get_valid_port "请输入 Hysteria 2 监听端口" "443")
    info "已设置监听端口为: ${hy2_port}"

    # 配置密码
    default_pwd=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)
    read -rp "请输入连接密码 [直接回车随机生成: ${default_pwd}]: " hy2_pwd
    hy2_pwd=${hy2_pwd:-$default_pwd}

    # 伪装域名
    read -rp "请输入伪装 SNI 域名 [默认 cn.bing.com，直接回车确认]: " sni_domain
    sni_domain=${sni_domain:-cn.bing.com}

    info "正在生成自签证书 (EC prime256v1)..."
    mkdir -p /etc/hysteria
    openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/server.key
    openssl req -new -x509 -days 3650 -key /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=${sni_domain}"

    if id -u hysteria &>/dev/null; then
        chown -R hysteria:hysteria /etc/hysteria
    fi

    info "写入 /etc/hysteria/config.yaml..."
    cat > /etc/hysteria/config.yaml << HY2_CONF
listen: :${hy2_port}

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: ${hy2_pwd}

resolver:
  type: udp
  tcp:
    addr: 8.8.8.8:53
    timeout: 4s
  udp:
    addr: 8.8.4.4:53
    timeout: 4s
  tls:
    addr: 1.1.1.1:853
    timeout: 10s
    sni: cloudflare-dns.com
    insecure: false
  https:
    addr: 1.1.1.1:443
    timeout: 10s
    sni: cloudflare-dns.com
    insecure: false

masquerade:
  type: proxy
  proxy:
    url: https://${sni_domain}/
    rewriteHost: true
HY2_CONF

    systemctl daemon-reload
    systemctl enable hysteria-server.service
    systemctl restart hysteria-server.service

    # 获取本机外网 IPv4
    server_ip=$(curl -s4m8 https://api.ipify.org || curl -s4m8 https://ipv4.icanhazip.com || echo "YOUR_SERVER_IP")

    echo ""
    info "==================== Hysteria 2 节点信息 ===================="
    echo -e "服务器地址 : ${server_ip}"
    echo -e "监听端口   : ${hy2_port}"
    echo -e "认证密码   : ${hy2_pwd}"
    echo -e "伪装域名   : ${sni_domain}"
    echo -e "跳过证书校验(Insecure): true (自签证书客户端需勾选允许不安全/跳过证书校验)"
    echo -e "\n客户端分享链接 (可直接导入 v2rayN / Clash Verge / Sing-box / Shadowrocket):"
    echo -e "${GREEN}hysteria2://${hy2_pwd}@${server_ip}:${hy2_port}/?sni=${sni_domain}&insecure=1#Hysteria2${PLAIN}"
    info "==========================================================="
    echo ""
}

# 5. 独立修改 Hysteria 2 监听端口
change_hy2_port() {
    local conf_file="/etc/hysteria/config.yaml"
    if [ ! -f "$conf_file" ]; then
        error "未检测到配置文件 ${conf_file}，请先安装 Hysteria 2！"
        return 1
    fi

    # 读取当前配置中的端口
    current_port=$(grep -E '^[[:space:]]*listen:' "$conf_file" | awk -F ':' '{print $NF}' | tr -d ' ' || echo "未知")
    info "当前 Hysteria 2 监听端口为: ${current_port}"

    new_port=$(get_valid_port "请输入新的监听端口" "443")

    # 替换端口配置
    sed -i -E "s/^[[:space:]]*listen:[[:space:]]*:[0-9]+/listen: :${new_port}/g" "$conf_file"
    systemctl restart hysteria-server.service

    # 读取当前密码与伪装域名用于输出链接
    hy2_pwd=$(grep -A 2 'auth:' "$conf_file" | grep 'password:' | awk '{print $2}' || echo "PASSWORD")
    sni_domain=$(openssl x509 -in /etc/hysteria/server.crt -noout -subject 2>/dev/null | sed -n 's/.*CN[ ]*=[ ]*//p' || echo "cn.bing.com")
    server_ip=$(curl -s4m8 https://api.ipify.org || curl -s4m8 https://ipv4.icanhazip.com || echo "YOUR_SERVER_IP")

    info "端口已成功修改为: ${new_port}，服务已重启！"
    echo -e "\n更新后的客户端链接:"
    echo -e "${GREEN}hysteria2://${hy2_pwd}@${server_ip}:${new_port}/?sni=${sni_domain}&insecure=1#Hysteria2${PLAIN}\n"
}

# 6. 安装 WARP-GO
install_warp_go() {
    info "开始安装 WARP-GO (fscarmen)..."
    wget -N https://gitlab.com/fscarmen/warp/-/raw/main/warp-go.sh && bash warp-go.sh d
}

# 7. 配置 Nginx 自启 (如果存在)
enable_nginx() {
    if command -v nginx &>/dev/null; then
        systemctl enable nginx
        systemctl restart nginx
        info "Nginx 开机自启与重启成功！"
    else
        warn "系统中未安装 Nginx，跳过此步。"
    fi
}

# 菜单入口
menu() {
    clear
    echo -e "=================================================="
    echo -e "         VPS 综合优化与节点一键安装工具           "
    echo -e "=================================================="
    echo -e " 1. 修复环境字符集 (en_US.UTF-8)"
    echo -e " 2. 开启 BBR 拥塞控制与 UDP 缓冲区调优"
    echo -e " 3. 安装 VLESS Reality (Mack-a 交互脚本)"
    echo -e " 4. 一键安装与配置 Hysteria 2"
    echo -e " 5. 单独修改 Hysteria 2 端口 (无需重装)"
    echo -e " 6. 安装 WARP-GO"
    echo -e " 7. 设置 Nginx 开机自启"
    echo -e " ------------------------------------------------"
    echo -e " 8. 【全套安装】按顺序执行全部步骤 (1 -> 2 -> 3 -> 4 -> 6)"
    echo -e " 0. 退出"
    echo -e "=================================================="
    read -rp "请输入选项 [0-8]: " choice

    case "$choice" in
        1) fix_environment ;;
        2) enable_bbr_and_sysctl ;;
        3) install_vless_reality ;;
        4) install_hysteria2 ;;
        5) change_hy2_port ;;
        6) install_warp_go ;;
        7) enable_nginx ;;
        8)
            fix_environment
            enable_bbr_and_sysctl
            install_vless_reality
            install_hysteria2
            install_warp_go
            enable_nginx
            ;;
        0) exit 0 ;;
        *) error "无效选项，请重新输入！" ;;
    esac
}

menu
