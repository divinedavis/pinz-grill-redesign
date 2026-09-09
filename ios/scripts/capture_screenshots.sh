#!/usr/bin/env bash
# Capture raw App Store screenshots on an iPhone 17 Pro Max (1320x2868) by
# running the MarketingScreenshots XCUITest, which writes PNGs straight to
# SCREENSHOT_DIR. Then compose the panels with asc_make_screenshots.py.
#
#   scripts/capture_screenshots.sh [out-dir]      # default build.nosync/screenshots-raw
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(cd "$(dirname "${1:-build.nosync/screenshots-raw}")" 2>/dev/null && pwd)/$(basename "${1:-build.nosync/screenshots-raw}")"
mkdir -p "$OUT"; rm -f "$OUT"/*.png
[[ -d PinzGrill.xcodeproj ]] || xcodegen generate >/dev/null

SIM="${SIMULATOR_ID:-}"
if [[ -z "$SIM" ]]; then
  SIM=$(xcrun simctl list devices available -j | python3 -c "import json,sys;d=json.load(sys.stdin);print(next(iter([dev['udid'] for r in d['devices'].values() for dev in r if dev.get('name')=='iPhone 17 Pro Max' and dev.get('isAvailable')]), ''))")
fi
[[ -n "$SIM" ]] || { echo "error: no iPhone 17 Pro Max simulator; pass SIMULATOR_ID" >&2; exit 1; }
xcrun simctl boot "$SIM" 2>/dev/null || true; xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || true
xcrun simctl status_bar "$SIM" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
echo "==> capturing on $SIM -> $OUT"
# Xcode forwards only TEST_RUNNER_-prefixed variables into the test runner.
TEST_RUNNER_SCREENSHOT_DIR="$OUT" xcodebuild test -project PinzGrill.xcodeproj -scheme PinzGrill \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath build.nosync/tests CODE_SIGNING_ALLOWED=NO \
  -only-testing:PinzGrillUITests/MarketingScreenshots 2>&1 | grep -E 'Test Case|error:|\*\*' | tail -20
xcrun simctl status_bar "$SIM" clear >/dev/null 2>&1 || true
ls -1 "$OUT"
