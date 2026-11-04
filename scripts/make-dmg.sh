#!/bin/sh
# Builds the app, then build/Espresso-<version>.dmg (drag-to-Applications disk image).
set -e
cd "$(dirname "$0")/.."
./scripts/build.sh
V=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
OUT="build/Espresso-$V.dmg"
STAGE=$(mktemp -d)
ditto build/Espresso.app "$STAGE/Espresso.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$OUT"
hdiutil create -volname Espresso -srcfolder "$STAGE" -fs HFS+ -format UDZO "$OUT" >/dev/null
rm -rf "$STAGE"
echo "Built $OUT"
