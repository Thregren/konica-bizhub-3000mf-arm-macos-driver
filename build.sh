#!/bin/zsh
#
# Build the native arm64 CUPS filter for KONICA MINOLTA bizhub
# 2600P / 3000MF / 3080MF (Brother ML13 engine, GDI/HBP printers).
#
# Requires: Xcode Command Line Tools (clang++ and the macOS SDK).

set -euo pipefail

cd "$(dirname "$0")"

SDKROOT="$(xcrun --show-sdk-path)"
OUT="dist/rastertobrlaser"

BUILD_DIR="$(mktemp -d /tmp/brlaser-build.XXXXXX)"
trap 'rm -rf "$BUILD_DIR"' EXIT

SOURCES=(src/main.cc src/job.cc src/line.cc src/debug.cc)
OBJECTS=()

for src in "${SOURCES[@]}"; do
  obj="$BUILD_DIR/$(basename "${src%.cc}").o"
  clang++ -std=c++11 -O2 -arch arm64 \
    -isysroot "$SDKROOT" \
    -I src \
    -Wall -Wno-missing-braces \
    -fstack-protector-strong -D_FORTIFY_SOURCE=2 \
    -c "$src" -o "$obj"
  OBJECTS+=("$obj")
done

clang++ -arch arm64 -isysroot "$SDKROOT" \
  "${OBJECTS[@]}" \
  -lcups -o "$OUT"

# All native code on Apple Silicon must carry at least an ad-hoc signature.
codesign -f -s - "$OUT"

echo "Built: $OUT"
lipo -info "$OUT"
