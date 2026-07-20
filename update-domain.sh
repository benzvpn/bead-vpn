#!/usr/bin/env bash
set -Eeuo pipefail

CONF_DIR="/etc/chaiya"
NGINX_SITE="/etc/nginx/sites-available/bead-vpn-panel"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

read -r -p "New domain: " DOMAIN
read -r -p "Issue SSL with certbot? y/n [y]: " USE_SSL
USE_SSL="${USE_SSL:-y}"
EMAIL=""
if [[ "$USE_SSL" == "y" || "$USE_SSL" == "Y" ]]; then
  read -r -p "SSL email, blank is allowed: " EMAIL
fi

if [[ -z "$DOMAIN" ]]; then
  echo "DOMAIN is required" >&2
  exit 1
fi

mkdir -p "$CONF_DIR"
printf '%s\n' "$DOMAIN" > "$CONF_DIR/domain.conf"

if [[ ! -f "$NGINX_SITE" ]]; then
  NGINX_SITE="$(grep -RIl -e '127[.]0[.]0[.]1:6789' -e '/opt/chaiya-panel' /etc/nginx/sites-available /etc/nginx/conf.d 2>/dev/null | head -1 || true)"
fi

if [[ -z "$NGINX_SITE" || ! -f "$NGINX_SITE" ]]; then
  echo "BEAD VPN nginx config was not found. Run install-bead-vpn-panel.sh first." >&2
  exit 1
fi

cp -a "$NGINX_SITE" "$NGINX_SITE.bak.$(date +%Y%m%d-%H%M%S)"
sed -i -E "s/server_name[[:space:]].*;/server_name $DOMAIN;/" "$NGINX_SITE"

nginx -t
systemctl reload nginx || systemctl restart nginx

if [[ "$USE_SSL" == "y" || "$USE_SSL" == "Y" ]]; then
  if [[ -n "$EMAIL" ]]; then
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect
  else
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect
  fi
fi

echo "Domain updated: https://$DOMAIN/"
