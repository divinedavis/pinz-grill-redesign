#!/usr/bin/env bash
# Pinz Grill — tests, smoke launch, bump build, archive, export, upload to TestFlight.
# Build number lives in project.yml (CURRENT_PROJECT_VERSION); the pbxproj is generated.
# Needs scripts/asc-config.env (gitignored) and an App Store Connect app record for
# com.divinedavis.pinzgrill — Apple's API cannot create that record; both xcodebuild
# ("Error Downloading App Information") and altool ("Cannot determine the Apple ID
# from Bundle ID") fail until it exists in the dashboard.
#   SHIP_RUN_UI=1       also gate on the XCUITest suite
#   SHIP_SKIP_TESTS=1   skip tests + smoke (re-upload of a known-good tree)
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f scripts/asc-config.env ]] || { echo "error: scripts/asc-config.env missing (copy .example)" >&2; exit 1; }
# shellcheck disable=SC1091
source scripts/asc-config.env
PROJECT="PinzGrill.xcodeproj"; SCHEME="PinzGrill"
ARCHIVE="build.nosync/PinzGrill.xcarchive"; EXPORT_DIR="build.nosync/export"

echo "==> refreshing bundled ChowNow snapshot"; python3 scripts/refresh_snapshot.py
xcodegen generate >/dev/null
if [[ "${SHIP_SKIP_TESTS:-0}" != "1" ]]; then
  echo "==> tests"
  if [[ "${SHIP_RUN_UI:-0}" == "1" ]]; then scripts/run_tests.sh; else scripts/run_tests.sh -only-testing:PinzGrillTests; fi
  echo "==> smoke launch"; scripts/smoke_test.sh
fi

current=$(grep -m1 'CURRENT_PROJECT_VERSION:' project.yml | sed -E 's/.*"([0-9]+)".*/\1/'); next=$((current + 1))
echo "==> bumping build $current -> $next"
sed -i '' "s/CURRENT_PROJECT_VERSION: \"$current\"/CURRENT_PROJECT_VERSION: \"$next\"/" project.yml
xcodegen generate >/dev/null

AUTH=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
echo "==> archiving"; rm -rf "$ARCHIVE" "$EXPORT_DIR"; mkdir -p build.nosync
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates "${AUTH[@]}" DEVELOPMENT_TEAM="$ASC_TEAM_ID" archive > build.nosync/archive.log 2>&1 \
  || { echo "error: archive failed" >&2; grep -E "error" build.nosync/archive.log | tail -20 >&2; exit 1; }
echo "==> exporting"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates "${AUTH[@]}" > build.nosync/export.log 2>&1 \
  || { echo "error: export failed" >&2; grep -iE "error" build.nosync/export.log | tail -20 >&2; exit 1; }
IPA=$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' | head -1)   # named after CFBundleName: "Pinz Grill.ipa"
[[ -f "$IPA" ]] || { echo "error: IPA missing" >&2; exit 1; }
echo "==> uploading to TestFlight"
xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
echo "==> shipped build $next — commit the project.yml bump"
