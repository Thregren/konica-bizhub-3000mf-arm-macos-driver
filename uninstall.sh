#!/bin/zsh
#
# Remove the files installed by install.sh.

set -euo pipefail

FILTER="/Library/Printers/KONICAMINOLTA/Filter/rastertobrlaser"
PPD_DIR="/Library/Printers/PPDs/Contents/Resources"

echo ">> 移除过滤器 $FILTER"
if [[ -f "$FILTER" ]]; then
  sudo rm -f "$FILTER"
fi

echo ">> 移除 PPD 描述文件"
for name in \
  "KONICA MINOLTA bizhub 3000MF (ARM)" \
  "KONICA MINOLTA bizhub 3080MF (ARM)" \
  "KONICA MINOLTA bizhub 2600P (ARM)"; do
  for ext in ppd ppd.gz; do
    f="$PPD_DIR/$name.$ext"
    if [[ -f "$f" ]]; then
      sudo rm -f "$f"
      echo "   removed: $name.$ext"
    fi
  done
done

echo ">> 重启 CUPS 服务"
sudo killall -HUP cupsd 2>/dev/null || true
sudo launchctl kickstart -k system/org.cups.cupsd 2>/dev/null || true

echo "卸载完成。已添加的打印队列不受影响（其 PPD 缓存仍保留）。"
