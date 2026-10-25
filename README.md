# 🚀 VPS 综合网络优化与节点一键部署管理脚本

[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu%20%7C%20CentOS-green.svg)]()
[![Shell](https://img.shields.io/badge/shell-bash-orange.svg)]()

专为新手与进阶 VPS 玩家打造的**全能网络优化与科学代理部署工具**。一键完成系统环境修复、TCP BBR 加速、UDP 高性能缓存调优、VLESS-Reality 与 Hysteria 2 双协议搭建，并支持 Cloudflare WARP IP 分流与解锁。

---

## 🌟 特性一览

- ⚡ **系统内核调优**：
  - 自动开启 **BBR 拥塞控制算法**与 `fq` 队列调度，提升弱网吞吐量。
  - **UDP 缓冲区深度调优**：将内核 `rmem_max` 与 `wmem_max` 提升至 16MB，消除 Hysteria 2 / QUIC 高并发丢包及日志报警。
- 🛡️ **双协议互补搭建**：
  - **VLESS-Reality**（基于 Mack-a 官方最新内核）：无需自备域名，借用大厂 TLS 握手特征，反 GFW 主动探测能力极强。
  - **Hysteria 2**（官方安装源）：基于 QUIC (UDP) 开发，专门优化恶劣网络环境，跑满带宽、超低延迟。
  - **完美共存**：VLESS-Reality 运行于 **TCP 443**，Hysteria 2 运行于 **UDP 443**，两者协议互不干扰，可同时绑定在 443 黄金端口上。
- 🔧 **交互友好与端口自由**：
  - Hysteria 2 安装时默认提供 `443` 端口（直接回车即可），亦支持用户自定义端口输入与边界合法性校验 (`1~65535`)。
  - **免 nano 手动改配置**：内置独立的端口修改功能，随时换端口，自动重启服务并重新生成分享链接。
- 🌐 **IP 分流与流媒体解锁**：
  - 集成 **WARP-GO**，为服务器添加 IPv4/IPv6 出站双栈，摆脱 Google 验证码并解锁 ChatGPT、Netflix、Disney+ 等区域限制。
- 🧰 **常见排错与自动化修复**：
  - 自动安装缺失依赖，修复 Debian / Ubuntu 系统常出现的缺少 `en_US.UTF-8` 语言环境及 Perl 警告问题。
  - 支持 Nginx 开机自启动检查与管理。

---

## ⚡ 快速开始

在全新或已有的 VPS（推荐 Debian 11/12、Ubuntu 20.04/22.04/24.04）上以 `root` 权限执行以下命令：

```bash
curl -fsSL https://raw.githubusercontent.com/philding123/proxy_on_vps/main/setup.sh -o setup.sh && chmod +x setup.sh && ./setup.sh
```

或使用 `wget`：

```bash
wget -N --no-check-certificate https://raw.githubusercontent.com/philding123/proxy_on_vps/main/setup.sh && chmod +x setup.sh && ./setup.sh
```

---

## 📋 菜单功能说明

运行脚本后，将出现如下交互菜单：

```text
==================================================
         VPS 综合优化与节点一键安装工具           
==================================================
 1. 修复环境字符集 (en_US.UTF-8)
 2. 开启 BBR 拥塞控制与 UDP 缓冲区调优
 3. 安装 VLESS Reality (Mack-a 交互脚本)
 4. 一键安装与配置 Hysteria 2
 5. 单独修改 Hysteria 2 端口 (无需重装)
 6. 安装 WARP-GO
 7. 设置 Nginx 开机自启
 ------------------------------------------------
 8. 【全套安装】按顺序执行全部步骤 (1 -> 2 -> 3 -> 4 -> 6)
 0. 退出
==================================================
```

### 推荐安装流程

- **全新 VPS 首次装机**：建议选择 `8. 【全套安装】`，按提示一站式配置好网络调优、双节点与出站分流。
- **自定义安装**：可按需选择 `1 -> 2 -> 3` 或 `4` 进行单独部署。
- **端口被限速/换端口**：直接运行脚本选择 `5. 单独修改 Hysteria 2 端口`，输入新端口即可完成热更新与链接重新生成。

---

## 💡 协议与端口详细说明

### 1. VLESS-Reality
- **协议类型**：TCP
- **推荐端口**：443
- **特点**：借用公网已有的优质证书域名（如 `cn.bing.com`、`www.apple.com` 等），不需要自己购买域名或申请证书，中间人无法解密或伪装握手。

### 2. Hysteria 2
- **协议类型**：UDP (QUIC)
- **推荐端口**：默认 443（亦可设为 8443、4433 或随机高端端口）
- **认证方式**：密码认证（脚本支持随机强密码生成或自定义输入）
- **证书机制**：内置生成标准 EC prime256v1 自签证书。
  - **重要提醒**：由于使用自签证书，在客户端导入或连接时，必须开启 **“跳过证书验证 / 允许不安全 (Insecure: true)”** 开关。

---

## 📱 客户端配置与推荐

脚本在完成 Hysteria 2 安装或端口修改后，会自动生成通用的 `hysteria2://` 分享链接，你可以复制该链接直接导入各平台主流代理客户端。

| 平台 | 推荐客户端 | 核心注意事项 |
| :--- | :--- | :--- |
| **Windows** | [v2rayN](https://github.com/2dust/v2rayN) / [Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev) / [Sing-box](https://github.com/SagerNet/sing-box) | v2rayN 需更新 core 至最新；勾选允许不安全证书 |
| **Android** | [v2rayNG](https://github.com/2dust/v2rayNG) / [NekoBox](https://github.com/MatsuriDayo/NekoBoxForAndroid) / [Sing-box](https://github.com/SagerNet/sing-box) | 支持扫码或剪贴板导入节点 |
| **macOS** | [Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev) / [Surge](https://nssurge.com/) / [Sing-box](https://github.com/SagerNet/sing-box) | 支持系统代理或增强 TUN 模式 |
| **iOS** | [Shadowrocket](https://apps.apple.com/app/shadowrocket/id932747118) / [Loon](https://apps.apple.com/app/loon/id1372230303) / [Stash](https://stash.ws/) | 扫描脚本生成的节点二维码或粘贴导入 |

---

## ❓ 常见问题排查 (FAQ)

### 1. 云服务器安全组/防火墙设置 (最常见连不上原因)
很多云服务商（如 Azure、Oracle Cloud 甲骨文、AWS、阿里云、腾讯云等）默认只放行了 TCP 22 端口。请务必前往**云控制台后台的安全组（Network Security Group / 防火墙）**添加入站规则：
- **TCP 443**（用于 VLESS-Reality）
- **UDP 443**（或你设置的 Hysteria 2 自定义端口，用于 QUIC）

### 2. 为什么需要调大 `rmem_max` 和 `wmem_max`？
Linux 默认的 UDP 缓冲区较小。当通过 Hysteria 2 进行高速下载或多连接并发时，操作系统的网络栈若来不及接收处理，就会直接丢弃 UDP 报文，导致断流或严重失速。脚本已将两个参数优化为 16MB 并持久化至 `/etc/sysctl.conf`。

### 3. 如何查看服务运行状态？
```bash
# 查看 Hysteria 2 运行状态
systemctl status hysteria-server.service

# 查看 Hysteria 2 实时日志
journalctl -u hysteria-server.service -f -n 50

# 查看 BBR 状态
sysctl net.ipv4.tcp_congestion_control
```

---

## 📄 开源许可

本项目依据 [MIT License](LICENSE) 开源。仅供个人学习网络技术、安全通信与服务器运维研究使用。
