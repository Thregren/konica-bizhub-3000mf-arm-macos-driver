#!/bin/zsh
#
# Build the unsigned printing-driver package published on GitHub Releases.
# Install it with Finder or:
#   sudo installer -pkg dist/*.pkg -target /

set -euo pipefail

cd "$(dirname "$0")"

export COPYFILE_DISABLE=1

VERSION="1.0.0"
PACKAGE="dist/KONICA-MINOLTA-bizhub-2600P-3000MF-3080MF-ARM-v${VERSION}.pkg"

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

# -X is required on macOS: the workspace may attach Finder/file-provider
# metadata that pkgbuild would otherwise serialize as ._* AppleDouble files.
cp -X dist/rastertobrlaser "$STAGE/root/Library/Printers/KONICAMINOLTA/Filter/rastertobrlaser"
chmod 755 "$STAGE/root/Library/Printers/KONICAMINOLTA/Filter/rastertobrlaser"

for ppd in ppd/*.ppd; do
  name="$(basename "$ppd" .ppd)"
  gzip -c "$ppd" > "$STAGE/root/Library/Printers/PPDs/Contents/Resources/$name.ppd.gz"
done

# The sandbox can attach com.apple.provenance to staging files. Building with
# pkgbuild would serialize those attributes as AppleDouble entries (._*). Build
# the standard flat-package members directly with cpio instead, excluding any
# metadata sidecars from the file list.
cat > "$STAGE/scripts/postinstall" <<'EOF'
#!/bin/zsh
set -e
killall -HUP cupsd 2>/dev/null || true
launchctl kickstart -k system/org.cups.cupsd 2>/dev/null || true
exit 0
EOF
chmod 755 "$STAGE/scripts/postinstall"

WORK="$STAGE/package"
mkdir -p "$WORK"

FILE_COUNT=$(find "$STAGE/root" -not -name '._*' -print | wc -l | tr -d ' ')
INSTALL_KBYTES=$(du -sk "$STAGE/root" | awk '{print $1}')

cat > "$WORK/PackageInfo" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<pkg-info overwrite-permissions="true" relocatable="false" identifier="com.konicaminolta.bizhub3000mf.arm-driver" postinstall-action="none" version="$VERSION" format-version="2" generator-version="Codex" install-location="/" auth="root">
    <payload numberOfFiles="$FILE_COUNT" installKBytes="$INSTALL_KBYTES"/>
    <bundle-version/>
    <upgrade-bundle/>
    <update-bundle/>
    <atomic-update-bundle/>
    <strict-identifier/>
    <relocate/>
    <scripts>
        <postinstall file="./postinstall" timeout="600"/>
    </scripts>
</pkg-info>
EOF

mkbom -s "$STAGE/root" "$WORK/Bom"
(cd "$STAGE/root" && COPYFILE_DISABLE=1 \
  find . -not -name '._*' -print | \
  COPYFILE_DISABLE=1 cpio -o --format odc 2>/dev/null | gzip -n > "$WORK/Payload")
(cd "$STAGE/scripts" && COPYFILE_DISABLE=1 \
  find . -not -name '._*' -print | \
  COPYFILE_DISABLE=1 cpio -o --format odc 2>/dev/null | gzip -n > "$WORK/Scripts")
(cd "$WORK" && xar -cf "$PWD/../final.pkg" --compression=none \
  Bom Payload Scripts PackageInfo)
mv "$WORK/../final.pkg" "$PACKAGE"
xattr -c "$PACKAGE" 2>/dev/null || true

echo "Built: $PACKAGE"
