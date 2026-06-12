#!/bin/bash
# Driver for SwiftDecision in the iOS Simulator.
# Usage: driver.sh <build|start|tap|text|ss|describe|stop|udid> [args]
# Coordinates for tap are DEVICE POINTS (402x874 on iPhone 17).
# Screenshots are 3x pixels (1206x2622) -> divide pixel coords by 3 to get tap points.
set -euo pipefail

# fb-idb's CLI is installed under the python.org user bin, not on default PATH
export PATH="$HOME/Library/Python/3.10/bin:$PATH"

DEVICE="${SD_DEVICE:-iPhone 17}"
BUNDLE_ID=com.miemieqiang.SwiftDecision
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
APP="$ROOT/build/Build/Products/Debug-iphonesimulator/SwiftDecision.app"

udid() {
  # prefer a booted device, fall back to the configured one
  xcrun simctl list devices booted | grep -oE '[0-9A-F]{8}-[0-9A-F-]{27}' | head -1 ||
    xcrun simctl list devices available | grep -F "$DEVICE (" | grep -oE '[0-9A-F]{8}-[0-9A-F-]{27}' | head -1
}

case "${1:-}" in
  udid) udid ;;
  build)
    xcodebuild -project "$ROOT/SwiftDecision.xcodeproj" -scheme SwiftDecision \
      -destination "platform=iOS Simulator,name=$DEVICE" \
      -derivedDataPath "$ROOT/build" build -quiet
    ;;
  start)
    xcrun simctl boot "$DEVICE" 2>/dev/null || true   # ok if already booted
    open -a Simulator
    xcrun simctl install booted "$APP"
    xcrun simctl launch booted "$BUNDLE_ID"
    ;;
  tap)  idb ui tap --udid "$(udid)" "$2" "$3" ;;
  text) idb ui text --udid "$(udid)" "$2" ;;   # ASCII only; use paste for CJK
  paste)
    # idb ui text has no keycodes for CJK; route via Mac clipboard + Cmd+V.
    # Needs Accessibility permission for the calling terminal, and a focused field.
    osascript - "$2" <<'EOF'
on run argv
  set the clipboard to (item 1 of argv)
  tell application "Simulator" to activate
  delay 0.3
  tell application "System Events" to keystroke "v" using command down
end run
EOF
    ;;
  ss)
    out="${2:-/tmp/swiftdecision-$(date +%H%M%S).png}"
    xcrun simctl io booted screenshot "$out" >/dev/null 2>&1
    echo "$out"
    ;;
  describe) idb ui describe-all --udid "$(udid)" ;;
  stop) xcrun simctl terminate booted "$BUNDLE_ID" ;;
  *) sed -n '2,5p' "$0"; exit 1 ;;
esac
