# Pinz Grill iOS app

SwiftUI app for [Pinz Grill](https://www.pinzgrill.com) (Columbia, SC). Home, live menu with
modifiers, pickup/delivery ordering, hours, contact and catering.

## How ordering works

ChowNow publishes no public ordering API. The only supported way to place an order is its
hosted checkout, so the app opens `direct.chownow.com/order/42710/locations/64455?mode=pickup|delivery`
in an in-app Safari sheet (`SafariView`). That keeps ChowNow logins, saved cards and Apple Pay,
and ChowNow handles the delivery courier (Flex Delivery) itself.

The menu, hours, delivery fee/minimum, discounts and rewards come from the same unauthenticated
read endpoints ChowNow's own ordering page uses (`api.chownow.com/api/restaurant/64455` and
`…/menu`). The app fetches them live on launch and when it returns to the foreground, caches
the last good copy, and ships a pruned snapshot in `PinzGrill/Resources/` as the offline fallback.

## Build

```
brew install xcodegen          # once
xcodegen generate
open PinzGrill.xcodeproj       # or:
scripts/smoke_test.sh          # build + install + cold launch in a simulator
scripts/run_tests.sh           # unit + UI tests
scripts/run_tests.sh -only-testing:PinzGrillTests
python3 scripts/refresh_snapshot.py               # refresh the bundled fallback
~/.venvs/spendcap/bin/python scripts/make_icon.py # regenerate the app icon (flame grill + Oswald wordmark)
scripts/ship.sh                                    # tests, smoke, bump, archive, TestFlight
```

Team `CG89RY4W6R`, bundle id `com.divinedavis.pinzgrill`, App Store Connect app `6809923608`.

## App Store listing (all in `scripts/`, run with `~/.venvs/spendcap/bin/python`)

1. `capture_screenshots.sh` on an iPhone 17 Pro Max, then `asc_make_screenshots.py` → `marketing/asc-screenshots/`.
2. `asc_metadata.py [--build N]` writes the whole listing (copy, category, price, availability, screenshots, review notes) and attaches the build. `--show` prints the live state.
3. `asc_push_privacy_iris.py` declares "Data Not Collected"; needs `fastlane spaceauth -u <apple id>` first (2FA, so a person runs it; 401 = expired cookie).
4. `asc_submit_for_review.py --check`, then without `--check` to submit.
5. The version is submitted with a **manual** release. After approval, `asc_release.py` puts it on the store.

The privacy policy and support pages live at `../privacy.html` and `../support.html` (deployed by `../deploy.sh`).
