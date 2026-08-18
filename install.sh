#!/bin/zsh
#
# Install the native arm64 KONICA MINOLTA bizhub 2600P / 3000MF / 3080MF
# print driver (open-source brlaser-based CUPS filter + PPDs).
#
# Usage:   zsh install.sh
# Uninstall: zsh uninstall.sh

set -euo pipefail

cd "$(dirname "$0")"

FILTER_SRC="dist/rastertobrlaser"
FILTER_DST="/Library/Printers/KONICAMINOLTA/Filter/rastertobrlaser"
PPD_DIR="/Library/Printers/PPDs/Contents/Resources"

if [[ ! -f "$FILTER_SRC" ]]; then
  echo "未找到 $FILTER_SRC，请先运行 zsh build.sh 编译。"
  exit 1
fi

if [[ $(uname -m) != "arm64" ]]; then
  echo "此驱动只适用于 Apple Silicon (arm64) Mac。"
  exit 1
fi

echo ">> 安装 arm64 原生过滤器到 $FILTER_DST"
sudo mkdir -p "$(dirname "$FILTER_DST")"
sudo cp "$FILTER_SRC" "$FILTER_DST"
sudo chmod 755 "$FILTER_DST"
sudo chown root:wheel "$FILTER_DST"

echo ">> 安装 PPD 描述文件"
sudo mkdir -p "$PPD_DIR"
for ppd in ppd/*.ppd; do
  name="$(basename "$ppd" .ppd)"
  dst="$PPD_DIR/$name.ppd.gz"
  gzip -c "$ppd" | sudo tee "$dst" >/dev/null
  sudo chmod 644 "$dst"
  sudo chown root:wheel "$dst"
  echo "   installed: $name.ppd.gz"
done

echo ">> 重启 CUPS 服务"
sudo killall -HUP cupsd 2>/dev/null || true
sudo launchctl kickstart -k system/org.cups.cupsd 2>/dev/null || true

echo
echo "安装完成。"
echo "添加打印机：系统设置 > 打印机与扫描仪 > 添加打印机，"
echo "“使用”一栏选择“选择软件”，然后选中对应的 KONICA MINOLTA bizhub 机型。"
echo
echo "网络打印也可用命令行注册，例如："
echo '  lpadmin -p Bizhub3000MF -E -v socket://<打印机IP>:9100 \'
echo "    -P \"/Library/Printers/PPDs/Contents/Resources/$(basename 'ppd/KONICA MINOLTA bizhub 3000MF (ARM).ppd').gz\""
