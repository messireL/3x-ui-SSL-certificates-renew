#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0.5"

BASE_DIR="/opt/3xuisslcert"
CONF_FILE="/etc/3xuisslcert.conf"
BIN_LINK="/usr/local/bin/xui-certctl"
LEGACY_LINK="/usr/local/sbin/xui-certctl"
PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MAIN_ID=""
SAN_IDS=""
CHALLENGE=""
WEBROOT=""
SERVICE=""
TARGET_BASE_DIR=""
TARGET_SUBDIR=""
ACME_HOME=""
UFW_TEMP_80=""
UFW_OPEN80_ONLY_WHEN_DUE=""
UFW_OPEN80_WINDOW_SEC=""
RUN_SYNC="yes"
AUTO="no"

usage() {
  cat <<'USG'
3xuisslcert installer
Version: 1.0.5

Project path:
  /opt/3xuisslcert

Examples:
  sudo bash install.sh
  sudo bash install.sh --auto
  sudo bash install.sh --id <ip-or-domain> --san <dns-name>

Options:
  --auto
  --id <ip-or-domain>              Optional. If omitted, installer auto-detects public IP.
  --san <ip-or-domain>             Repeatable.
  --challenge standalone|webroot
  --webroot <path>
  --service <name>
  --target-base-dir <path>
  --acme-home <path>
  --ufw-temp80 auto|yes|no
  --ufw-window-sec <seconds>
  --ufw-open80-only-when-due yes|no
  --no-sync

Migration:
- legacy binary /usr/local/sbin/xui-certctl is replaced with a compatibility symlink
- legacy cron /etc/cron.d/xui-certctl is removed
- current cert binding is reinstalled to update reloadcmd
USG
}

need_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "ERROR: run as root"; exit 1; }
}

default_if_empty() {
  local var="$1" val="$2"
  if [[ -z "${!var:-}" ]]; then
    printf -v "$var" '%s' "$val"
  fi
}

detect_public_ip() {
  local ip=""
  if command -v curl >/dev/null 2>&1; then
    for u in "https://api.ipify.org" "https://ifconfig.me" "https://icanhazip.com"; do
      ip="$(curl -fsS --max-time 5 "$u" 2>/dev/null | tr -d ' \n\r\t' || true)"
      [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && { echo "$ip"; return 0; }
    done
  fi
  if command -v wget >/dev/null 2>&1; then
    ip="$(wget -qO- --timeout=5 https://api.ipify.org 2>/dev/null | tr -d ' \n\r\t' || true)"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && { echo "$ip"; return 0; }
  fi
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' || true)"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && { echo "$ip"; return 0; }
  fi
  echo ""
}

detect_fqdn() {
  local h=""
  h="$(hostname -f 2>/dev/null || true)"
  [[ "$h" == *.* && "$h" != "localhost" && "$h" != "localhost.localdomain" ]] && echo "$h" || echo ""
}

prompt_default() {
  local __var="$1" __prompt="$2" __def="$3"
  local __val=""
  read -r -p "$__prompt [$__def]: " __val || true
  [[ -z "$__val" ]] && __val="$__def"
  printf -v "$__var" '%s' "$__val"
}

load_existing_config() {
  if [[ -f "$CONF_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONF_FILE"
  elif [[ -f /etc/xui-certctl.conf ]]; then
    # shellcheck disable=SC1090
    source /etc/xui-certctl.conf
    [[ -z "${MAIN_ID:-}" && -n "${ID:-}" ]] && MAIN_ID="$ID"
  fi
}

rebind_current_cert() {
  [[ -n "${MAIN_ID:-}" ]] || return 0
  [[ -x "$ACME_HOME/acme.sh" ]] || return 0

  if "$ACME_HOME/acme.sh" --home "$ACME_HOME" --list 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$MAIN_ID"; then
    echo "Rebinding acme install paths and reloadcmd for current MAIN_ID=$MAIN_ID ..."
    "$ACME_HOME/acme.sh" --home "$ACME_HOME" --install-cert -d "$MAIN_ID" --ecc \
      --fullchain-file "$TARGET_BASE_DIR/$TARGET_SUBDIR/$MAIN_ID/fullchain.pem" \
      --key-file       "$TARGET_BASE_DIR/$TARGET_SUBDIR/$MAIN_ID/private.key" \
      --reloadcmd      "$BASE_DIR/xui-certctl postdeploy" || true
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto) AUTO="yes"; shift 1 ;;
    --id) MAIN_ID="${2:-}"; shift 2 ;;
    --san) SAN_IDS="${SAN_IDS:-} ${2:-}"; shift 2 ;;
    --challenge) CHALLENGE="${2:-}"; shift 2 ;;
    --webroot) WEBROOT="${2:-}"; shift 2 ;;
    --service) SERVICE="${2:-}"; shift 2 ;;
    --target-base-dir) TARGET_BASE_DIR="${2:-}"; shift 2 ;;
    --acme-home) ACME_HOME="${2:-}"; shift 2 ;;
    --ufw-temp80) UFW_TEMP_80="${2:-}"; shift 2 ;;
    --ufw-window-sec) UFW_OPEN80_WINDOW_SEC="${2:-}"; shift 2 ;;
    --ufw-open80-only-when-due) UFW_OPEN80_ONLY_WHEN_DUE="${2:-}"; shift 2 ;;
    --no-sync) RUN_SYNC="no"; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown: $1"; usage; exit 1 ;;
  esac
done

need_root
load_existing_config

default_if_empty CHALLENGE "standalone"
default_if_empty WEBROOT "/var/www/html"
default_if_empty SERVICE "x-ui"
default_if_empty TARGET_BASE_DIR "/root/cert"
default_if_empty TARGET_SUBDIR "ip"
default_if_empty ACME_HOME "/root/.acme.sh"
default_if_empty UFW_TEMP_80 "auto"
default_if_empty UFW_OPEN80_ONLY_WHEN_DUE "yes"
default_if_empty UFW_OPEN80_WINDOW_SEC "900"

det_ip="$(detect_public_ip)"
det_fqdn="$(detect_fqdn)"

if [[ "$AUTO" == "yes" ]]; then
  echo "Auto-detect: IP=${det_ip:-<none>} FQDN=${det_fqdn:-<none>}"
  [[ -z "${MAIN_ID:-}" ]] && prompt_default MAIN_ID "MAIN_ID" "${det_ip:-}"
  if [[ -n "$det_fqdn" && "$det_fqdn" != "$MAIN_ID" ]]; then
    read -r -p "Add hostname to SAN? ($det_fqdn) [y/N]: " a || true
    case "${a,,}" in
      y|yes) SAN_IDS="${SAN_IDS:-} $det_fqdn" ;;
    esac
  fi
fi

if [[ -z "${MAIN_ID:-}" ]]; then
  MAIN_ID="$det_ip"
fi

SAN_IDS="$(echo "${SAN_IDS:-}" | xargs 2>/dev/null || true)"
[[ -n "${MAIN_ID:-}" ]] || { echo "ERROR: MAIN_ID empty and public IP autodetect failed"; exit 1; }

echo "Installing 3xuisslcert v$VERSION into $BASE_DIR ..."
mkdir -p "$BASE_DIR"
install -m 0755 "$PKG_DIR/files/xui-certctl" "$BASE_DIR/xui-certctl"
ln -sfn "$BASE_DIR/xui-certctl" "$BIN_LINK"
ln -sfn "$BASE_DIR/xui-certctl" "$LEGACY_LINK"

cat >"$CONF_FILE" <<EOF
VERSION="$VERSION"
BASE_DIR="$BASE_DIR"
MAIN_ID="$MAIN_ID"
SAN_IDS="$SAN_IDS"
ACME_HOME="$ACME_HOME"
TARGET_BASE_DIR="$TARGET_BASE_DIR"
TARGET_SUBDIR="$TARGET_SUBDIR"
SERVICE="$SERVICE"
CHALLENGE="$CHALLENGE"
WEBROOT="$WEBROOT"
UFW_TEMP_80="$UFW_TEMP_80"
UFW_OPEN80_ONLY_WHEN_DUE="$UFW_OPEN80_ONLY_WHEN_DUE"
UFW_OPEN80_WINDOW_SEC="$UFW_OPEN80_WINDOW_SEC"
UFW_COMMENT="3xuisslcert-acme-temp"
RELOAD_CMD="$BASE_DIR/xui-certctl postdeploy"
EOF
chmod 0644 "$CONF_FILE"

mkdir -p "$TARGET_BASE_DIR/$TARGET_SUBDIR"
chmod 700 "$TARGET_BASE_DIR" || true

if [[ "$MAIN_ID" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || [[ "$SAN_IDS" =~ ([0-9]{1,3}\.){3}[0-9]{1,3} ]]; then
  CRON_EXPR="12 */6 * * *"
else
  CRON_EXPR="12 4,16 * * *"
fi

cat >/etc/cron.d/3xuisslcert <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
$CRON_EXPR root $BASE_DIR/xui-certctl sync >/dev/null 2>&1
EOF
chmod 0644 /etc/cron.d/3xuisslcert
rm -f /etc/cron.d/xui-certctl

echo "cron installed: /etc/cron.d/3xuisslcert ($CRON_EXPR)"

rebind_current_cert

if [[ "$RUN_SYNC" == "yes" ]]; then
  "$BASE_DIR/xui-certctl" sync
  "$BASE_DIR/xui-certctl" status || true
fi

echo "Done."
