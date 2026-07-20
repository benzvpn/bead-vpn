#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run as root: sudo $0 <domain> <panel-user> <panel-pass> [ssl:y/n] [email]" >&2
  exit 1
fi

DOMAIN="${1:-${DOMAIN:-}}"
ADMIN_USER="${2:-${ADMIN_USER:-admin}}"
ADMIN_PASS="${3:-${ADMIN_PASS:-}}"
USE_SSL="${4:-${USE_SSL:-y}}"
EMAIL="${5:-${EMAIL:-}}"

if [[ -z "$DOMAIN" || -z "$ADMIN_USER" || -z "$ADMIN_PASS" ]]; then
  cat >&2 <<'EOF'
Usage:
  sudo ./quick-install.sh your-domain.com admin your-panel-password

Optional:
  sudo ./quick-install.sh your-domain.com admin your-panel-password y admin@example.com
  sudo ./quick-install.sh your-domain.com admin your-panel-password n
EOF
  exit 1
fi

export DOMAIN ADMIN_USER ADMIN_PASS USE_SSL EMAIL NONINTERACTIVE=1
exec "$SCRIPT_DIR/install-bead-vpn-panel.sh"
