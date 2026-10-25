# proxy_on_vps

One-key script to install a Hysteria 2 (hy2) proxy server on a VPS.

## Quick start

```bash
chmod +x /home/runner/work/proxy_on_vps/proxy_on_vps/install_hy2.sh
sudo /home/runner/work/proxy_on_vps/proxy_on_vps/install_hy2.sh
```

## Optional environment variables

- `PORT` (default: `443`) - UDP listen port
- `DOMAIN` - domain for ACME TLS certificate issuance (recommended)
- `EMAIL` (default: `admin@example.com`) - email used by ACME when `DOMAIN` is set

Example:

```bash
sudo DOMAIN=your.domain.com EMAIL=you@example.com PORT=443 /home/runner/work/proxy_on_vps/proxy_on_vps/install_hy2.sh
```

If `DOMAIN` is not set, the script falls back to a self-signed certificate.