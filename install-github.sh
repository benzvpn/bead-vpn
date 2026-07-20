#!/usr/bin/env bash
set -Eeuo pipefail

GITHUB_REPO="benzvpn"
GITHUB_BRANCH="bead-vpn"

DOMAIN="${1:-}"
ADMIN_USER="${2:-admin}"
ADMIN_PASS="${3:-}"
USE_SSL="${4:-y}"
EMAIL="${5:-}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run as root or sudo." >&2
  exit 1
fi

if [[ -z "$GITHUB_REPO" || -z "$DOMAIN" || -z "$ADMIN_USER" || -z "$ADMIN_PASS" ]]; then
  cat >&2 <<'EOF'
Usage:
  sudo GITHUB_REPO=benzvpn/bead-vpn bash install-github.sh domain.com admin panel-password

From GitHub raw URL:
  curl -fsSL https://raw.githubusercontent.com/benzvpn/bead-vpn/main/install-github.sh -o /tmp/install-github.sh
  sudo GITHUB_REPO=benzvpn/bead-vpn bash /tmp/install-github.sh domain.com admin panel-password
EOF
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl unzip

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

ZIP_URL="https://github.com/${GITHUB_REPO}/archive/refs/heads/${GITHUB_BRANCH}.zip"
curl -fL "$ZIP_URL" -o "$WORKDIR/source.zip"
unzip -q "$WORKDIR/source.zip" -d "$WORKDIR"

PKG_DIR="$(find "$WORKDIR" -maxdepth 2 -type d -name bead-vpn-install | head -1)"
if [[ -z "$PKG_DIR" || ! -f "$PKG_DIR/install-bead-vpn-panel.sh" ]]; then
  echo "bead-vpn-install folder was not found in ${GITHUB_REPO}:${GITHUB_BRANCH}" >&2
  exit 1
fi

chmod +x "$PKG_DIR"/*.sh
DOMAIN="$DOMAIN" \
ADMIN_USER="$ADMIN_USER" \
ADMIN_PASS="$ADMIN_PASS" \
USE_SSL="$USE_SSL" \
EMAIL="$EMAIL" \
NONINTERACTIVE=1 \
"$PKG_DIR/install-bead-vpn-panel.sh"
