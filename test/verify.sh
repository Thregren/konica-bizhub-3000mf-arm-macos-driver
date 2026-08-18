#!/bin/zsh
#
# Local end-to-end sanity check without a printer:
#   text -> macOS cgpdftoraster -> arm64 rastertobrlaser -> PJL/HBP bytes.

set -euo pipefail

cd "$(dirname "$0")/.."

TMP="$(mktemp -d /tmp/km-verify.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

PPD="ppd/KONICA MINOLTA bizhub 3000MF (ARM).ppd"

echo "== 1. text -> PDF"
cupsfilter -i text/plain -m application/pdf test/print-test.txt > "$TMP/test.pdf" 2>/dev/null

echo "== 2. PDF -> CUPS raster (600dpi, A4, duplex, toner save)"
cupsfilter -P "$PPD" -m application/vnd.cups-raster \
  -o Resolution=600dpi -o PageSize=A4 -o MediaType=PLAIN \
  -o InputSlot=Auto "$TMP/test.pdf" > "$TMP/test.raster" 2>/dev/null

echo "== 3. CUPS raster -> printer bytes"
dist/rastertobrlaser 1 "$USER" "verify" 1 \
  "Duplex=DuplexNoTumble brlaserEconomode=True" \
  "$TMP/test.raster" > "$TMP/out.prn" 2>"$TMP/filter.log"

echo "== filter version and architecture"
head -1 "$TMP/filter.log"
file dist/rastertobrlaser | sed 's/^/   /'

echo "== PJL header emitted"
strings -a "$TMP/out.prn" | rg 'PJL|1030m|&l' | head -12

echo
echo "OK: 本地链路验证通过（未连接打印机，仅验证数据生成）。"
