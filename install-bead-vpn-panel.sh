#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PANEL_DIR="/opt/chaiya-panel"
API_DIR="/opt/chaiya-ssh-api"
CONF_DIR="/etc/chaiya"
BACKUP_DIR="/root/bead-vpn-backups/$(date +%Y%m%d-%H%M%S)"
NGINX_SITE="/etc/nginx/sites-available/bead-vpn-panel"

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run as root: sudo $0" >&2
    exit 1
  fi
}

ask() {
  local var_name="$1"
  local label="$2"
  local default_value="${3:-}"
  local value=""
  local current_value="${!var_name:-}"
  if [[ -n "$current_value" ]]; then
    return
  fi
  if [[ "${NONINTERACTIVE:-0}" == "1" ]]; then
    printf -v "$var_name" '%s' "$default_value"
    return
  fi
  if [[ -n "$default_value" ]]; then
    read -r -p "$label [$default_value]: " value
    value="${value:-$default_value}"
  else
    read -r -p "$label: " value
  fi
  printf -v "$var_name" '%s' "$value"
}

backup_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    mkdir -p "$BACKUP_DIR$(dirname "$path")"
    cp -a "$path" "$BACKUP_DIR$path"
  fi
}

install_packages() {
  apt-get update
  apt-get install -y \
    ca-certificates curl nginx certbot python3-certbot-nginx \
    python3 openssh-server dropbear websockify iproute2
}

install_files() {
  for file in app.py index.html sshws.html; do
    if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
      echo "Missing $SCRIPT_DIR/$file" >&2
      exit 1
    fi
  done

  backup_path "$PANEL_DIR/index.html"
  backup_path "$PANEL_DIR/sshws.html"
  backup_path "$API_DIR/app.py"

  mkdir -p "$PANEL_DIR" "$API_DIR" "$CONF_DIR/exp"
  install -m 0755 "$SCRIPT_DIR/app.py" "$API_DIR/app.py"
  install -m 0644 "$SCRIPT_DIR/index.html" "$PANEL_DIR/index.html"
  install -m 0644 "$SCRIPT_DIR/sshws.html" "$PANEL_DIR/sshws.html"
}

write_chaiya_config() {
  local ip
  ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ { for (i=1;i<=NF;i++) if ($i=="src") { print $(i+1); exit } }')"
  mkdir -p "$CONF_DIR"
  printf '%s\n' "$DOMAIN" > "$CONF_DIR/domain.conf"
  printf '%s\n' "${ip:-}" > "$CONF_DIR/my_ip.conf"
  printf '%s\n' "$ADMIN_USER" > "$CONF_DIR/xui-user.conf"
  printf '%s\n' "$ADMIN_PASS" > "$CONF_DIR/xui-pass.conf"
  touch "$CONF_DIR/ssh_links.json"
  chmod 600 "$CONF_DIR/xui-user.conf" "$CONF_DIR/xui-pass.conf" "$CONF_DIR/ssh_links.json"
}

configure_ssh_services() {
  systemctl enable ssh >/dev/null 2>&1 || systemctl enable sshd >/dev/null 2>&1 || true
  systemctl restart ssh >/dev/null 2>&1 || systemctl restart sshd >/dev/null 2>&1 || true

  backup_path /etc/default/dropbear
cat >/etc/default/dropbear <<'EOF'
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143"
DROPBEAR_BANNER=""
DROPBEAR_RECEIVE_WINDOW=65536
EOF
  systemctl enable dropbear
  systemctl restart dropbear
}

write_systemd() {
  cat >/etc/systemd/system/chaiya-ssh-api.service <<EOF
[Unit]
Description=BEAD VPN SSH API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $API_DIR/app.py
Restart=always
RestartSec=2
User=root
WorkingDirectory=$API_DIR

[Install]
WantedBy=multi-user.target
EOF

  cat >/etc/systemd/system/bead-ws-ssh.service <<'EOF'
[Unit]
Description=BEAD VPN WebSocket to SSH bridge
After=network-online.target dropbear.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/websockify --heartbeat=30 127.0.0.1:10080 127.0.0.1:109
Restart=always
RestartSec=2
User=root

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now chaiya-ssh-api
  systemctl enable --now bead-ws-ssh
}

write_nginx() {
  backup_path "$NGINX_SITE"
  cat >"$NGINX_SITE" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    root $PANEL_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:6789/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /ssh {
        proxy_pass http://127.0.0.1:10080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
EOF
  ln -sf "$NGINX_SITE" /etc/nginx/sites-enabled/bead-vpn-panel
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl enable nginx
  systemctl reload nginx || systemctl restart nginx
}

issue_ssl() {
  if [[ "$USE_SSL" != "y" && "$USE_SSL" != "Y" ]]; then
    return
  fi
  if [[ -n "$EMAIL" ]]; then
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect
  else
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect
  fi
}

print_summary() {
  cat <<EOF

Install complete
URL: https://$DOMAIN/
Login: $ADMIN_USER

Service:
  chaiya-ssh-api: $(systemctl is-active chaiya-ssh-api || true)
  bead-ws-ssh:    $(systemctl is-active bead-ws-ssh || true)
  nginx:          $(systemctl is-active nginx || true)
  dropbear:       $(systemctl is-active dropbear || true)

Backup: $BACKUP_DIR
EOF
}

main() {
  need_root
  ask DOMAIN "New domain, example vpn.example.com"
  ask ADMIN_USER "Panel username" "admin"
  ask ADMIN_PASS "Panel password"
  ask USE_SSL "Issue SSL with certbot? y/n" "y"
  EMAIL="${EMAIL:-}"
  if [[ "$USE_SSL" == "y" || "$USE_SSL" == "Y" ]]; then
    ask EMAIL "SSL email, blank is allowed" ""
  fi

  if [[ -z "$DOMAIN" || -z "$ADMIN_USER" || -z "$ADMIN_PASS" ]]; then
    echo "DOMAIN, ADMIN_USER, ADMIN_PASS are required" >&2
    exit 1
  fi

  install_packages
  install_files
  write_chaiya_config
  configure_ssh_services
  write_systemd
  write_nginx
  issue_ssl
  print_summary
}

main "$@"
