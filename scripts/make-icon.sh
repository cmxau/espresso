#!/bin/sh
# Regenerates Resources/AppIcon.icns from the Cup shape.
set -e
cd "$(dirname "$0")/.."
T=$(mktemp -d); mkdir "$T/AppIcon.iconset"
swiftc -o "$T/icon" Sources/Espresso/Cup.swift scripts/icon/main.swift
"$T/icon" "$T/AppIcon.iconset"
iconutil -c icns "$T/AppIcon.iconset" -o Resources/AppIcon.icns
rm -rf "$T"
