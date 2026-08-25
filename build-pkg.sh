#!/bin/zsh
#
# Build an (unsigned) flat installer package for convenience.
# Primary supported install path is install.sh; use this package with:
#   sudo installer -pkg dist/*.pkg -target /

set -euo pipefail

cd "$(dirname "$0")"

export COPYFILE_DISABLE=1

if [[ ! -f dist/rastertobrlaser ]]; then
  echo "先运行 zsh build.sh"
  exit 1
fi

STAGE="$(mktemp -d /tmp/km-pkg.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p \
  "$STAGE/root/Library/Printers/KONICAMINOLTA/Filter" \
  "$STAGE/root/Library/Printers/PPDs/Contents/Resources" \
  "$STAGE/scripts"

cp dist/rastertobrlaser "$STAGE/root/Library/Printers/KONICAMINOLTA/Filter/rastertobrlaser"
chmod 755 "$STAGE/root/Library/Printers/KONICAMINOLTA/Filter/rastertobrlaser"

for ppd in ppd/*.ppd; do
  name="$(basename "$ppd" .ppd)"
  gzip -c "$ppd" > "$STAGE/root/Library/Printers/PPDs/Contents/Resources/$name.ppd.gz"
done

# Do not ship AppleDouble (._*) metadata files inside the package.
find "$STAGE/root" -name '._*' -delete
# Strip extended attributes (e.g. com.apple.provenance) so pkgbuild does not
# synthesize AppleDouble entries for them.
xattr -cr "$STAGE/root" 2>/dev/null || true

cat > "$STAGE/scripts/postinstall" <<'EOF'
#!/bin/zsh
set -e
killall -HUP cupsd 2>/dev/null || true
launchctl kickstart -k system/org.cups.cupsd 2>/dev/null || true
exit 0
EOF
chmod 755 "$STAGE/scripts/postinstall"

pkgbuild \
  --root "$STAGE/root" \
  --scripts "$STAGE/scripts" \
  --identifier com.konicaminolta.bizhub3000mf.arm-driver \
  --version "1.1.0" \
  --install-location / \
  "dist/KONICA-MINOLTA-bizhub-2600P-3000MF-3080MF-ARM-1.1.0.pkg"

echo "Built: dist/KONICA-MINOLTA-bizhub-2600P-3000MF-3080MF-ARM-1.1.0.pkg"
