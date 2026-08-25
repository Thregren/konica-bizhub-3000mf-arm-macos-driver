#!/bin/bash
#
# Build a Linux (.deb) driver package for the bizhub 2600P/3000MF/3080MF
# from linux/.  Run on the target architecture (or in a matching container).
#
# Usage:  scripts/build-linux-deb.sh [ARCH] [VERSION]

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
ARCH="${1:-$(dpkg --print-architecture 2>/dev/null || echo amd64)}"
VERSION="${2:-1.1.0}"
PKG="konica-bizhub-2600p-3000mf-3080mf"
FILTER="rastertobrlaser"

BUILD="$ROOT/build/linux/$ARCH"
DEBROOT="$BUILD/debroot"
rm -rf "$DEBROOT"
mkdir -p "$DEBROOT/DEBIAN" \
         "$DEBROOT/usr/lib/cups/filter" \
         "$DEBROOT/usr/share/cups/model/konica" \
         "$DEBROOT/usr/share/doc/$PKG"

echo ">> Building $FILTER for $ARCH"
make -C "$ROOT/linux" clean >/dev/null 2>&1 || true
make -C "$ROOT/linux" all

echo ">> Staging package"
install -m 755 "$ROOT/linux/$FILTER" "$DEBROOT/usr/lib/cups/filter/$FILTER"
for ppd in "$ROOT"/linux/ppd/*.ppd; do
  [ -f "$ppd" ] || continue
  install -m 644 "$ppd" "$DEBROOT/usr/share/cups/model/konica/"
done

cat > "$DEBROOT/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION-1
Architecture: $ARCH
Maintainer: Thregren <thregren@users.noreply.github.com>
Installed-Size: $(du -sk "$DEBROOT" | awk '{print $1}')
Section: utils
Priority: optional
Homepage: https://github.com/Thregren/konica-bizhub-3000mf-arm-macos-driver
Description: KONICA MINOLTA bizhub 2600P/3000MF/3080MF CUPS printer driver (brlaser/HBP)
 Linux CUPS filter and PPD for printing to these Brother-engine Konica machines.
 .
 The filter reads application/vnd.cups-raster and emits the printer's
 native PJL/HBP stream. No vendor binaries are used.
EOF

cat > "$DEBROOT/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v systemctl >/dev/null 2>&1 && [ -e /run/systemd/system ]; then
  systemctl restart cups 2>/dev/null || systemctl restart cups.service 2>/dev/null || true
else
  killall -HUP cupsd 2>/dev/null || pkill -HUP cupsd 2>/dev/null || true
fi
exit 0
EOF
chmod 755 "$DEBROOT/DEBIAN/postinst"

cat > "$DEBROOT/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
if command -v systemctl >/dev/null 2>&1 && [ -e /run/systemd/system ]; then
  systemctl restart cups 2>/dev/null || systemctl restart cups.service 2>/dev/null || true
else
  killall -HUP cupsd 2>/dev/null || pkill -HUP cupsd 2>/dev/null || true
fi
exit 0
EOF
chmod 755 "$DEBROOT/DEBIAN/prerm"

cat > "$DEBROOT/usr/share/doc/$PKG/copyright" <<'EOF'
This package is based on the brlaser project:
  brlaser - Copyright (C) 2013 Peter De Wachter <pdewacht@gmail.com>
  License: GNU General Public License version 2 or (at your option) any later.
  Upstream: https://github.com/pdewacht/brlaser
EOF
if [ -f "$ROOT/linux/LICENSE" ]; then
  install -m 644 "$ROOT/linux/LICENSE" "$DEBROOT/usr/share/doc/$PKG/LICENSE"
fi

echo ">> Building .deb"
DEB="$BUILD/${PKG}_${VERSION}-1_${ARCH}.deb"
DEBROOT_TMP="$(mktemp -d)"
cp -a "$DEBROOT/." "$DEBROOT_TMP/"
dpkg-deb --build --root-owner-group "$DEBROOT_TMP" "$DEB" >/dev/null
rm -rf "$DEBROOT_TMP"

echo ">> Done: $DEB"
