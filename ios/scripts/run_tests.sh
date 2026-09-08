#!/usr/bin/env bash
# Unit + UI tests on a booted simulator. Pass -only-testing:PinzGrillTests to skip the UI suite.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -d PinzGrill.xcodeproj ]] || xcodegen generate >/dev/null
SIM=$(xcrun simctl list devices available -j | python3 -c "import json,sys;d=json.load(sys.stdin);print(next(iter([dev['udid'] for r in d['devices'].values() for dev in r if 'iPhone' in dev.get('name','') and dev.get('isAvailable')]), ''))")
xcrun simctl boot "$SIM" 2>/dev/null || true; xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || true
xcodebuild test -project PinzGrill.xcodeproj -scheme PinzGrill -destination "platform=iOS Simulator,id=$SIM" \
  -derivedDataPath build.nosync/tests CODE_SIGNING_ALLOWED=NO "$@" 2>&1 | grep -E 'Test Case|error:|passed|failed|\*\*' | tail -40
