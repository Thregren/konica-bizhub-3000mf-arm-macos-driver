#!/bin/bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

echo ">> Building Linux filter"
make -C "$ROOT/linux" all
echo ">> Installing to /usr (CUPS)"
sudo make -C "$ROOT/linux" install

echo ">> Restarting CUPS"
if command -v systemctl >/dev/null 2>&1 && [ -e /run/systemd/system ]; then
  systemctl restart cups
else
  killall -HUP cupsd 2>/dev/null || pkill -HUP cupsd 2>/dev/null || true
fi

echo
echo "已安装。用对应的 /usr/share/cups/model/konica/KONICA MINOLTA bizhub *.ppd 添加打印机。"
