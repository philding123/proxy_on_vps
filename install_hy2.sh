#!/usr/bin/env bash

set -euo pipefail

PORT="${PORT:-443}"
CONFIG_DIR="/etc/hysteria"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
TOKEN_FILE="${CONFIG_DIR}/auth.txt"
CERT_FILE="${CONFIG_DIR}/server.crt"
KEY_FILE="${CONFIG_DIR}/server.key"
DOMAIN="${DOMAIN:-}"
EMAIL="${EMAIL:-}"
SERVICE_NAME="hysteria-server.service"

usage() {
  cat <<'EOF'
One-key installer for Hysteria 2 (hy2) server on VPS.

Usage:
  sudo bash install_hy2.sh

Optional environment variables:
  PORT=443                 UDP listen port for hy2 server
  DOMAIN=example.com       Domain used for ACME TLS certificate (recommended)
  EMAIL=you@example.com    Email used for ACME registration when DOMAIN is set (optional)

If DOMAIN is not set, the script generates a self-signed certificate.
EOF
}

log() {
  printf '[hy2-install] %s\n' "$1"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run as root (or with sudo)." >&2
    exit 1
  fi
}

install_dependencies() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget openssl ca-certificates
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y curl wget openssl ca-certificates
  elif command -v yum >/dev/null 2>&1; then
    yum install -y curl wget openssl ca-certificates
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache curl wget openssl ca-certificates
  else
    echo "Unsupported package manager. Install curl, wget, openssl manually." >&2
    exit 1
  fi
}

install_hysteria() {
  if command -v hysteria >/dev/null 2>&1; then
    log "hysteria is already installed. Skipping binary install."
    return
  fi

  log "Installing hysteria (hy2 server)..."
  bash <(curl -fsSL https://get.hy2.sh/)
}

generate_auth_token() {
  mkdir -p "${CONFIG_DIR}"
  if [[ -s "${TOKEN_FILE}" ]]; then
    cat "${TOKEN_FILE}"
    return
  fi

  local auth_token
  auth_token="$(openssl rand -hex 16)"
  printf '%s\n' "${auth_token}" >"${TOKEN_FILE}"
  chmod 600 "${TOKEN_FILE}"
  printf '%s\n' "${auth_token}"
}

write_self_signed_config() {
  mkdir -p "${CONFIG_DIR}"
  if [[ ! -s "${CERT_FILE}" || ! -s "${KEY_FILE}" ]]; then
    openssl req -x509 -nodes -newkey rsa:2048 \
      -keyout "${KEY_FILE}" -out "${CERT_FILE}" -days 3650 \
      -subj "/CN=$(hostname -f 2>/dev/null || hostname)"
  fi
  chmod 600 "${KEY_FILE}"
  chmod 644 "${CERT_FILE}"
  if id -u hysteria >/dev/null 2>&1; then
    chown hysteria:hysteria "${KEY_FILE}" "${CERT_FILE}"
  fi

  cat >"${CONFIG_FILE}" <<EOF
listen: :${PORT}
tls:
  cert: ${CERT_FILE}
  key: ${KEY_FILE}
auth:
  type: password
  password: ${1}
masquerade:
  type: proxy
  proxy:
    url: https://www.cloudflare.com
    rewriteHost: true
EOF
}

write_acme_config() {
  cat >"${CONFIG_FILE}" <<EOF
listen: :${PORT}
acme:
  domains:
    - ${DOMAIN}
EOF
  if [[ -n "${EMAIL}" ]]; then
    cat >>"${CONFIG_FILE}" <<EOF
  email: ${EMAIL}
EOF
  fi
  cat >>"${CONFIG_FILE}" <<EOF
auth:
  type: password
  password: ${1}
masquerade:
  type: proxy
  proxy:
    url: https://www.cloudflare.com
    rewriteHost: true
EOF
}

restart_service() {
  if ! systemctl cat "${SERVICE_NAME}" >/dev/null 2>&1; then
    echo "Expected ${SERVICE_NAME} not found. Verify hy2 installation output." >&2
    exit 1
  fi

  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}"
  systemctl restart "${SERVICE_NAME}"
}

get_public_ipv4() {
  curl -s4m8 https://api.ipify.org || curl -s4m8 https://ipv4.icanhazip.com || true
}

print_summary() {
  local host sni insecure share_link
  if [[ -n "${DOMAIN}" ]]; then
    host="${DOMAIN}"
    sni="${DOMAIN}"
    insecure="0"
  else
    host="$(get_public_ipv4)"
    if [[ -z "${host}" ]]; then
      host="$(hostname -f 2>/dev/null || hostname)"
    fi
    sni="$(hostname -f 2>/dev/null || hostname)"
    insecure="1"
  fi
  share_link="hysteria2://${1}@${host}:${PORT}/?sni=${sni}&insecure=${insecure}#Hysteria2"

  cat <<EOF

==================== hy2 server installed ====================
Server: ${host}
Port (UDP): ${PORT}
Password: ${1}
Config: ${CONFIG_FILE}
Service: ${SERVICE_NAME}
EOF

  if [[ -n "${DOMAIN}" ]]; then
    cat <<EOF
TLS mode: ACME (${DOMAIN}) via built-in certificate issuance
ACME note: Open inbound TCP 80 and ensure nothing else (e.g. nginx) listens on 80.
EOF
  else
    cat <<'EOF'
TLS mode: self-signed certificate
Client note: set insecure=true (or import the generated cert) on clients.
EOF
  fi

  cat <<EOF
Share link: ${share_link}
==============================================================
EOF
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  require_root
  install_dependencies
  install_hysteria

  local auth_token
  auth_token="$(generate_auth_token)"
  if [[ -n "${DOMAIN}" ]]; then
    write_acme_config "${auth_token}"
  else
    write_self_signed_config "${auth_token}"
  fi

  restart_service
  print_summary "${auth_token}"
}

main "$@"
