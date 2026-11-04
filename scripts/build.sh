#!/bin/sh
# Builds build/Espresso.app (ad-hoc signed) with SwiftPM; no Xcode project needed.
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP=build/Espresso.app
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Espresso" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --options runtime --sign - "$APP"
echo "Built $APP"
