#!/usr/bin/env python3
"""Declare the App Privacy label ("Data Not Collected") through the private
iris API the App Store Connect dashboard uses.

The public API has no appDataUsages resource (every path 404s), so this posts
to /iris/v1 with the cookie jar fastlane's Spaceship writes after a login:

    fastlane spaceauth -u <apple id>        # 2FA prompt; refreshes the cookie
    python3 scripts/asc_push_privacy_iris.py

The app collects nothing: no accounts, no analytics, no location; ordering
happens on ChowNow's page in SFSafariViewController, outside the app's process.
That is one appDataUsages record with dataProtection DATA_NOT_COLLECTED and no
category or purpose (what fastlane's upload_app_privacy_details sends for
"not collecting"), followed by the publish-state PATCH. The publish state can
only be UPDATEd, never read, so a 200 on the PATCH is the proof.
"""
from __future__ import annotations
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from asc_metadata import load_config  # noqa: E402
import requests

IRIS = "https://appstoreconnect.apple.com/iris/v1"
COOKIE_FILE = pathlib.Path.home() / ".fastlane" / "spaceship" / "divinejdavis@gmail.com" / "cookie"


def session() -> requests.Session:
    if not COOKIE_FILE.exists():
        raise SystemExit(f"no Spaceship cookie at {COOKIE_FILE}; run: fastlane spaceauth -u divinejdavis@gmail.com")
    s = requests.Session()
    cur: dict = {}
    for line in COOKIE_FILE.read_text().splitlines():
        if line.lstrip().startswith("- !ruby/object:"):
            if cur.get("name") and cur.get("value"):
                s.cookies.set(cur["name"], cur["value"], domain=cur.get("domain", "appstoreconnect.apple.com"))
            cur = {}; continue
        k, _, v = line.strip().partition(":")
        if k in ("name", "value", "domain") and v.strip():
            cur[k] = v.strip().strip('"').strip("'")
    if cur.get("name") and cur.get("value"):
        s.cookies.set(cur["name"], cur["value"], domain=cur.get("domain", "appstoreconnect.apple.com"))
    s.headers.update({"Accept": "application/vnd.api+json", "Content-Type": "application/vnd.api+json",
                      "X-Requested-With": "XMLHttpRequest", "Origin": "https://appstoreconnect.apple.com",
                      "Referer": "https://appstoreconnect.apple.com/",
                      "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"})
    return s


def main() -> int:
    app_id = load_config()["ASC_APP_ID"]
    s = session()
    r = s.get(f"{IRIS}/apps/{app_id}", timeout=20)
    if r.status_code == 401:
        raise SystemExit("iris session expired (401). Run: fastlane spaceauth -u divinejdavis@gmail.com  then re-run this script")
    r.raise_for_status()
    existing = s.get(f"{IRIS}/appDataUsages", params={"filter[app]": app_id, "limit": 50}, timeout=20)
    existing.raise_for_status()
    rows = existing.json().get("data", [])
    if any(((d.get("relationships") or {}).get("dataProtection") or {}).get("data", {}).get("id") == "DATA_NOT_COLLECTED" for d in rows):
        print("   already declared: Data Not Collected")
    else:
        for d in rows:   # anything else on file would contradict "not collected"
            s.delete(f"{IRIS}/appDataUsages/{d['id']}", timeout=20).raise_for_status()
        body = {"data": {"type": "appDataUsages", "relationships": {
            "app": {"data": {"type": "apps", "id": app_id}},
            "dataProtection": {"data": {"type": "appDataUsageDataProtections", "id": "DATA_NOT_COLLECTED"}}}}}
        r = s.post(f"{IRIS}/appDataUsages", data=json.dumps(body), timeout=30)
        if r.status_code >= 400:
            raise SystemExit(f"POST appDataUsages -> {r.status_code}\n{r.text[:800]}")
        print("   ✓ Data Not Collected")
    r = s.patch(f"{IRIS}/appDataUsagesPublishState/{app_id}", timeout=30,
                data=json.dumps({"data": {"type": "appDataUsagesPublishState", "id": app_id, "attributes": {"published": True}}}))
    if r.status_code >= 400:
        raise SystemExit(f"publish -> {r.status_code}\n{r.text[:800]}")
    print("   ✓ published")
    return 0


if __name__ == "__main__":
    sys.exit(main())
