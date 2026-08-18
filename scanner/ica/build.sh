#!/bin/zsh
#
# Build the arm64 ICA scanner device module for Image Capture.
# Output: scanner/ica/build/KMBizhubScanner.app

set -euo pipefail

cd "$(dirname "$0")"

SDKROOT="$(xcrun --show-sdk-path)"
APP="build/KMBizhubScanner.app"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp KMBizhubScanner/Info.plist "$APP/Contents/Info.plist"
cp KMBizhubScanner/Resources/*.plist "$APP/Contents/Resources/"

xattr -cr "$APP" 2>/dev/null || true

xcrun clang -fobjc-arc -fno-modules -Wno-deprecated-declarations \
  -arch arm64 -isysroot "$SDKROOT" \
  -I KMBizhubScanner -I ../protocol \
  -framework Cocoa \
  -framework ICADevices \
  -framework IOKit \
  -framework CoreGraphics \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  -framework CoreServices \
  KMBizhubScanner/main.m \
  KMBizhubScanner/EntryPoints.m \
  KMBizhubScanner/KMScannerDevice.mm \
  KMBizhubScanner/KMScannedImage.m \
  ../protocol/brscan.cpp \
  -lc++ \
  -o "$APP/Contents/MacOS/KMScannerModule"

SIGNED=0
for attempt in 1 2 3; do
  xattr -cr "$APP" 2>/dev/null || true
  xattr -d com.apple.FinderInfo "$APP" 2>/dev/null || true
  xattr -d com.apple.fileprovider.fpfs#P "$APP" 2>/dev/null || true
  if codesign -f -s - "$APP" 2>/dev/null; then
    SIGNED=1
    break
  fi
done
if [[ "$SIGNED" != "1" ]]; then
  echo "codesign failed: the bundle has persistent extended attributes" >&2
  exit 1
fi

echo "Built: $APP"
lipo -info "$APP/Contents/MacOS/KMScannerModule"
