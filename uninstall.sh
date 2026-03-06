#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "ERROR: run as root"
  exit 1
fi

rm -f /etc/cron.d/3xuisslcert
rm -f /etc/cron.d/xui-certctl
rm -f /usr/local/bin/xui-certctl
rm -f /etc/3xuisslcert.conf
rm -rf /opt/3xuisslcert

echo "Removed 3xuisslcert"
