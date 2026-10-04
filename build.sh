#!/bin/bash
# Build StayAwake.app — a menu bar toggle that keeps the Mac awake.
set -euo pipefail

cd "$(dirname "$0")"

APP="StayAwake.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc \
  -O \
  -parse-as-library \
  -target arm64-apple-macos13.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework ServiceManagement \
  -o "$APP/Contents/MacOS/StayAwake" \
  StayAwakeApp.swift

cp Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so macOS runs it without a developer certificate.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "note: ad-hoc signing failed, app may need a manual Gatekeeper allow"

echo "built $APP"