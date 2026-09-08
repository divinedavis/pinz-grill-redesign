#!/usr/bin/env python3
"""Refresh the bundled ChowNow snapshot the app boots from.

ChowNow's hosted ordering page (direct.chownow.com) reads its location and
menu from api.chownow.com with no auth. The app fetches the same two
documents live on launch; these files are the fallback for a cold launch
with no network and the fixture the unit/UI tests run against.

Pruned before writing: everything the app never reads plus anything that
is not ours to redistribute (the Stripe publishable key under `membership`,
ad slots, Google Place data).

Usage: python3 scripts/refresh_snapshot.py   (stdlib only)
"""
import json, pathlib, urllib.request

HQ, LOCATION = "42710", "64455"
OUT = pathlib.Path(__file__).resolve().parent.parent / "PinzGrill" / "Resources"
UA = {"User-Agent": "PinzGrill-iOS snapshot (https://www.pinzgrill.com)"}
DROP = {"membership", "payment_processor_id", "google_place_actions_data",
        "transactional_ads", "redeemed_discounts", "native_app_versions",
        "is_favorite", "delivery_only_maps"}

def get(path):
    req = urllib.request.Request(f"https://api.chownow.com/api/{path}", headers=UA)
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)

restaurant = {k: v for k, v in get(f"restaurant/{LOCATION}").items() if k not in DROP}
menu = get(f"restaurant/{LOCATION}/menu")
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "restaurant.json").write_text(json.dumps(restaurant, indent=1))
(OUT / "menu.json").write_text(json.dumps(menu, indent=1))
cats = menu["menu_categories"]
print(f"restaurant: {restaurant['name']}  pickup_now={restaurant['fulfillment']['pickup']['is_available_now']}  "
      f"delivery_now={restaurant['fulfillment']['delivery']['is_available_now']}")
print(f"menu: {len(cats)} categories, {sum(len(c['items']) for c in cats)} items, "
      f"{len(menu['modifier_categories'])} modifier groups -> {OUT}")
