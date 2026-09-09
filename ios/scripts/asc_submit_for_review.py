#!/usr/bin/env python3
"""Submit the editable App Store version to App Review.

Pre-flights every field the public API can see (copy, build, review contact,
screenshots, category, privacy URL) and only fires the reviewSubmission when
they are all set. App Privacy and pricing are NOT visible to this check; a 409
on submit carries the real reason in meta.associatedErrors, which is printed.

    python3 scripts/asc_submit_for_review.py --check    # pre-flight only
    python3 scripts/asc_submit_for_review.py            # submit
"""
from __future__ import annotations
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from asc_metadata import ASC, API, EDITABLE, load_config  # noqa: E402


def main() -> int:
    cfg = load_config(); asc = ASC(cfg); app_id = cfg["ASC_APP_ID"]
    versions = asc.get(f"/apps/{app_id}/appStoreVersions", limit=5)["data"]
    ver = next((v for v in versions if v["attributes"]["appStoreState"] in EDITABLE), None)
    if not ver:
        raise SystemExit("no editable appStoreVersion")
    vid = ver["id"]
    print(f"→ version {ver['attributes']['versionString']} ({ver['attributes']['appStoreState']})")

    issues = []
    loc = next((l for l in asc.get(f"/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]
                if l["attributes"]["locale"] == "en-US"), None)
    if not loc:
        issues.append("missing en-US localization")
    else:
        for f in ("description", "keywords", "supportUrl"):
            if not loc["attributes"].get(f):
                issues.append(f"localization.{f} empty")
        sets = asc.get(f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
        ready = 0
        for s in sets:
            if s["attributes"]["screenshotDisplayType"].startswith("APP_IPHONE"):
                shots = asc.get(f"/appScreenshotSets/{s['id']}/appScreenshots")["data"]
                ready += sum(1 for x in shots if (x["attributes"].get("assetDeliveryState") or {}).get("state") == "COMPLETE")
        if ready < 3:
            issues.append(f"only {ready} iPhone screenshot(s) ready (need ≥ 3)")
    if not asc.get(f"/appStoreVersions/{vid}/build").get("data"):
        issues.append("no build attached")
    rd = asc.get(f"/appStoreVersions/{vid}/appStoreReviewDetail").get("data")
    if not rd:
        issues.append("no appStoreReviewDetail")
    else:
        for f in ("contactFirstName", "contactPhone", "contactEmail"):
            if not rd["attributes"].get(f):
                issues.append(f"reviewDetail.{f} empty")
    info = asc.get(f"/apps/{app_id}/appInfos")["data"][0]
    full = asc._ok(asc.s.get(f"{API}/appInfos/{info['id']}", params={"include": "primaryCategory,appInfoLocalizations"}, timeout=30))
    if not full["data"].get("relationships", {}).get("primaryCategory", {}).get("data"):
        issues.append("appInfo.primaryCategory unset")
    for inc in full.get("included", []):
        if inc["type"] == "appInfoLocalizations" and inc["attributes"].get("locale") == "en-US" and not inc["attributes"].get("privacyPolicyUrl"):
            issues.append("appInfoLocalization.privacyPolicyUrl empty")

    if issues:
        print("⚠ pre-flight gaps:"); [print("  -", x) for x in issues]
        return 1
    print("✓ pre-flight clean (App Privacy and pricing are not visible here)")
    if "--check" in sys.argv:
        return 0

    subs = asc.get("/reviewSubmissions", **{"filter[app]": app_id, "filter[platform]": "IOS", "limit": 10})["data"]
    draft = next((s for s in subs if s["attributes"].get("state") in ("READY_FOR_REVIEW", "UNRESOLVED_ISSUES")), None)
    if draft:
        sub_id = draft["id"]; print(f"→ reusing reviewSubmission {sub_id}")
    else:
        sub_id = asc.post("/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                          "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]["id"]
        print(f"→ created reviewSubmission {sub_id}")
    items = asc.get(f"/reviewSubmissions/{sub_id}/items").get("data", [])
    if not any((it.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id") == vid for it in items):
        asc.post("/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
        print("→ added the version as a submission item")
    r = asc.s.patch(f"{API}/reviewSubmissions/{sub_id}", json={"data": {"type": "reviewSubmissions", "id": sub_id,
                    "attributes": {"submitted": True}}}, timeout=30)
    if r.status_code >= 400:
        print(f"✗ submit -> {r.status_code}")
        try:
            for e in r.json().get("errors", []):
                print("  ", e.get("detail"))
                for a in (e.get("meta") or {}).get("associatedErrors", {}).values():
                    for x in a:
                        print("    -", x.get("detail"))
        except json.JSONDecodeError:
            print(r.text[:800])
        return 2
    print("✅ submitted to App Review")
    return 0


if __name__ == "__main__":
    sys.exit(main())
