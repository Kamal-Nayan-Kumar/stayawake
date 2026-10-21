#!/bin/bash
# Runs the checks that guard this repo.
#
#   ./test.sh
#
# Covers four things: the app builds, the bundle that comes out is well
# formed, the power assertion mechanism works on this machine, and the app
# itself actually holds and releases the assertion.
set -uo pipefail

cd "$(dirname "$0")"

APP="StayAwake.app"
DOMAIN="com.nayan.stayawake"
KEY_STAY_AWAKE="com.nayan.stayawake.stayAwake"
KEY_DISPLAY_SLEEP="com.nayan.stayawake.allowDisplaySleep"

BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stayawake-test.XXXXXX")"

FAILED=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }
section() { printf '\n%s\n' "$1"; }

# The end to end test flips the app's saved settings, so put them back
# afterwards no matter how the test ends.
saved_stay=""
saved_display=""
restore_settings() {
  if [ -n "$saved_stay" ]; then
    defaults write "$DOMAIN" "$KEY_STAY_AWAKE" -bool "$saved_stay" >/dev/null 2>&1
  else
    defaults delete "$DOMAIN" "$KEY_STAY_AWAKE" >/dev/null 2>&1
  fi
  if [ -n "$saved_display" ]; then
    defaults write "$DOMAIN" "$KEY_DISPLAY_SLEEP" -bool "$saved_display" >/dev/null 2>&1
  else
    defaults delete "$DOMAIN" "$KEY_DISPLAY_SLEEP" >/dev/null 2>&1
  fi
}
cleanup() {
  restore_settings
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

saved_stay=$(defaults read "$DOMAIN" "$KEY_STAY_AWAKE" 2>/dev/null)
saved_display=$(defaults read "$DOMAIN" "$KEY_DISPLAY_SLEEP" 2>/dev/null)

section "build"
if ./build.sh >/dev/null 2>&1; then
  pass "app builds"
else
  fail "app builds"
  exit 1
fi

section "bundle"
if [ -x "$APP/Contents/MacOS/StayAwake" ]; then
  pass "executable present and runnable"
else
  fail "executable present and runnable"
fi

if [ -f "$APP/Contents/Info.plist" ]; then
  pass "Info.plist present"
else
  fail "Info.plist present"
fi

if [ -f "$APP/Contents/Resources/AppIcon.icns" ]; then
  pass "app icon present"
else
  fail "app icon present"
fi

if /usr/libexec/PlistBuddy -c "Print :LSUIElement" "$APP/Contents/Info.plist" 2>/dev/null | grep -qi true; then
  pass "runs in the menu bar only, no dock icon"
else
  fail "runs in the menu bar only, no dock icon"
fi

MIN_VERSION=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$APP/Contents/Info.plist" 2>/dev/null)
if [ -n "$MIN_VERSION" ]; then
  pass "declares a minimum macOS version ($MIN_VERSION)"
else
  fail "declares a minimum macOS version"
fi

if codesign --verify --deep --strict "$APP" >/dev/null 2>&1; then
  pass "code signature is valid"
else
  fail "code signature is valid"
fi

ARCH=$(uname -m)
if lipo -info "$APP/Contents/MacOS/StayAwake" 2>/dev/null | grep -q "$ARCH"; then
  pass "binary architecture matches this Mac ($ARCH)"
else
  fail "binary architecture matches this Mac ($ARCH)"
fi

section "power assertion mechanism"
if swiftc -O -o "$BUILD_DIR/verify" Tools/verify.swift >/dev/null 2>&1; then
  pass "verifier compiles"
  if "$BUILD_DIR/verify" >"$BUILD_DIR/verify.log" 2>&1; then
    pass "macOS accepts and releases the assertion"
  else
    fail "macOS accepts and releases the assertion"
    sed -n 's/^/        /p' "$BUILD_DIR/verify.log"
  fi
else
  fail "verifier compiles"
fi

section "the running app"
# Start the app with Stay Awake already switched on and the display allowed
# to sleep, which is the "keep the Mac up, let the screen rest" mode.
defaults write "$DOMAIN" "$KEY_STAY_AWAKE" -bool true >/dev/null 2>&1
defaults write "$DOMAIN" "$KEY_DISPLAY_SLEEP" -bool true >/dev/null 2>&1

"$APP/Contents/MacOS/StayAwake" >/dev/null 2>&1 &
APP_PID=$!
sleep 3

assertions=$(pmset -g assertions 2>/dev/null)

if echo "$assertions" | grep -q "StayAwake.*PreventUserIdleSystemSleep"; then
  pass "the app holds the system sleep assertion"
else
  fail "the app holds the system sleep assertion"
  echo "$assertions" | sed -n 's/^/        /p'
fi

if echo "$assertions" | grep -q "StayAwake.*PreventUserIdleDisplaySleep"; then
  fail "the app lets the display sleep when asked to"
else
  pass "the app lets the display sleep when asked to"
fi

kill "$APP_PID" >/dev/null 2>&1
wait "$APP_PID" 2>/dev/null
sleep 1

if pmset -g assertions 2>/dev/null | grep -qi "stayawake"; then
  fail "the assertion is released when the app quits"
else
  pass "the assertion is released when the app quits"
fi

section "result"
if [ "$FAILED" -eq 0 ]; then
  echo "  all checks passed"
  exit 0
fi
echo "  some checks failed"
exit 1
