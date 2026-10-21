#!/bin/bash
# Builds StayAwake.app, a menu bar toggle that keeps the Mac awake.
#
# Needs the Xcode Command Line Tools:
#   xcode-select --install
#
# Output is StayAwake.app in the repo root. Move it to /Applications to
# install it.
set -euo pipefail

cd "$(dirname "$0")"

APP="StayAwake.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Compile. SwiftPM keeps the compiler flags in Package.swift instead of
# scattering them through shell, and matches what Xcode would do.
swift build -c release --product StayAwake
cp "$(swift build -c release --show-bin-path)/StayAwake" "$APP/Contents/MacOS/StayAwake"

cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so macOS runs it without a developer certificate. Apps using
# SMAppService must be signed, and ad-hoc is enough for that.
codesign --force --sign - "$APP" >/dev/null 2>&1 \
  || echo "note: ad-hoc signing failed, the app may need a manual Gatekeeper allow"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
echo "built $APP (version $VERSION, $(uname -m))"
