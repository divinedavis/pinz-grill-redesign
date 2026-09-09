#!/usr/bin/env python3
"""Write the App Store listing for Pinz Grill through the API.

Everything App Store Connect accepts over its API lives here, so the listing
is a file in the repo rather than a memory of which boxes were ticked:
content-rights declaration, category, subtitle, description, keywords, promo
text, URLs, copyright, release type, the age-rating questionnaire, the review
contact + notes, the free price, territory availability (every territory and
new ones as Apple adds them), the 6.7" screenshots from marketing/asc-screenshots/,
and the build the version ships with. Idempotent.

    python3 scripts/asc_metadata.py                 # apply everything
    python3 scripts/asc_metadata.py --build 3       # …and attach that build
    python3 scripts/asc_metadata.py --show          # print what is there now

Browser/private-API only: the App Privacy questionnaire
(scripts/asc_push_privacy_iris.py) and Submit for Review
(scripts/asc_submit_for_review.py, which uses the reviewSubmissions resource).
"""
from __future__ import annotations
import hashlib, os, pathlib, sys, time
import jwt, requests

HERE = pathlib.Path(__file__).resolve().parent
HOST = "https://api.appstoreconnect.apple.com"
API = HOST + "/v1"
SHOTS = HERE.parent / "marketing" / "asc-screenshots"

SUBTITLE = "Order ahead in Columbia, SC"                              # <= 30 chars
KEYWORDS = "wings,burgers,pizza,columbia sc,takeout,pickup,delivery,patty melt,hot dogs,catering,order ahead"  # <= 100
PROMO = ("Wings sauced eight ways, burgers, patty melts and pizza from Broad River Road. "
         "Start a pickup or delivery order in two taps, straight from the restaurant.")
SITE = "https://www.pinzgrill.com/"
SUPPORT = "https://divinedavis.com/pinz-grill/support.html"
PRIVACY = "https://divinedavis.com/pinz-grill/privacy.html"
COPYRIGHT = "2026 Divine Davis"
PRIMARY_CATEGORY = "FOOD_AND_DRINK"
# MANUAL: approval does not publish. The listing carries a real restaurant's
# name and artwork under the developer's own account, so the go-live click is
# left for after the owner has seen it — scripts/asc_release.py flips it.
RELEASE_TYPE = "MANUAL"

DESCRIPTION = """Pinz Grill is the wings, burger and pizza spot at 3601 Broad River Road in Columbia, South Carolina. This app puts the whole menu in your pocket and starts your order in two taps.

ORDER AHEAD
Choose pickup or delivery and check out on Pinz Grill's own secure online ordering, with Apple Pay, saved cards and your order history. No marketplace markups: the order goes straight to the restaurant.

THE FULL MENU, LIVE
Wings sauced eight ways, tenders, burgers, patty melts on Texas toast, jumbo hot dogs, 7" and 16" pizzas, loaded fries, nachos, kids meals and party packs of 30 to 100 wings. Prices, sauces and add-ons come straight from the restaurant's ordering system, so what you see is what you get.

KNOW BEFORE YOU GO
Open-now status, today's pickup and delivery hours, the delivery fee and minimum, current deals and rewards, one-tap directions and a tap-to-call button.

CATERING
Wing packages, tenders, burgers, pizza and sides for 10 to 200 people. Call to book from the Info tab.

Wings, Hot Dogs, Hamburgers & More. Made to order on Broad River Road.
"""

REVIEW_NOTES = """WHAT THE APP DOES
An ordering companion for Pinz Grill, a restaurant at 3601 Broad River Rd, Columbia, SC (pinzgrill.com). The Home, Menu, Order and Info tabs show the restaurant's live menu, hours, deals and contact details, read from the same public endpoints its online ordering page (direct.chownow.com) uses.

ORDERING
Tapping Pickup or Delivery opens the restaurant's existing ChowNow hosted checkout in an in-app Safari view (SFSafariViewController). Payment, accounts and order history are handled entirely by ChowNow on that page; the app itself takes no payment and stores no personal data. Placing an order there charges a real card and sends a real order to the kitchen, so please stop at the checkout screen.

NO SIGN-IN
No account is needed anywhere in the app, so no demo credentials are provided.

OFFLINE
If the menu endpoint is unreachable the app shows a bundled copy of the menu and says "Saved copy" under Info > About.

WHO BUILT IT
Developed by Divine Davis (the developer of record and the contact above) as the restaurant's ordering app. The app links only to the restaurant's own ordering system and website. Happy to provide any documentation App Review needs.
"""

AGE_RATING = {
    "alcoholTobaccoOrDrugUseOrReferences": "NONE", "contests": "NONE", "gamblingSimulated": "NONE",
    "gunsOrOtherWeapons": "NONE", "horrorOrFearThemes": "NONE", "matureOrSuggestiveThemes": "NONE",
    "medicalOrTreatmentInformation": "NONE", "profanityOrCrudeHumor": "NONE",
    "sexualContentGraphicAndNudity": "NONE", "sexualContentOrNudity": "NONE",
    "violenceCartoonOrFantasy": "NONE", "violenceRealistic": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
    "advertising": False, "ageAssurance": False, "gambling": False, "healthOrWellnessTopics": False,
    "lootBox": False, "messagingAndChat": False, "parentalControls": False,
    "unrestrictedWebAccess": False, "userGeneratedContent": False,
    "ageRatingOverride": "NONE",
}
EDITABLE = ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY")


def load_config() -> dict:
    p = HERE / "asc-config.env"
    if not p.exists():
        raise SystemExit("missing scripts/asc-config.env")
    cfg = {}
    for line in p.read_text().splitlines():
        s = line.strip()
        if s and not s.startswith("#"):
            k, _, v = s.partition("=")
            cfg[k.strip()] = os.path.expandvars(v.strip().strip('"').strip("'"))
    return cfg


class ASC:
    def __init__(self, cfg):
        key = pathlib.Path(cfg["ASC_KEY_PATH"]).expanduser().read_text()
        now = int(time.time())
        tok = jwt.encode({"iss": cfg["ASC_ISSUER_ID"], "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"},
                         key, algorithm="ES256", headers={"kid": cfg["ASC_KEY_ID"], "typ": "JWT"})
        self.s = requests.Session()
        self.s.headers.update({"Authorization": f"Bearer {tok}", "Content-Type": "application/json"})

    def _ok(self, r, ok=(200, 201, 204)):
        if r.status_code not in ok:
            raise SystemExit(f"{r.request.method} {r.url} -> {r.status_code}\n{r.text[:800]}")
        return r.json() if r.text else {}

    def get(self, path, **params):
        soft = path.endswith("appStoreReviewDetail") or path.endswith("/build")
        return self._ok(self.s.get(API + path, params=params, timeout=30), ok=(200, 404) if soft else (200,))

    def patch(self, path, body): return self._ok(self.s.patch(API + path, json=body, timeout=30))
    def post(self, path, body): return self._ok(self.s.post(API + path, json=body, timeout=30))
    def delete(self, path): return self._ok(self.s.delete(API + path, timeout=30))

    def builds(self, app_id):
        """Newest first, including ones still processing (the /builds filter hides those)."""
        out = []
        for v in self.get("/preReleaseVersions", **{"filter[app]": app_id, "limit": 50})["data"]:
            out += self.get(f"/preReleaseVersions/{v['id']}/builds", limit=50)["data"]
        out.sort(key=lambda b: b["attributes"].get("uploadedDate") or "", reverse=True)
        return out


def resolve(asc, app_id, any_version=False):
    info = asc.get(f"/apps/{app_id}/appInfos")["data"][0]
    versions = asc.get(f"/apps/{app_id}/appStoreVersions", limit=10)["data"]
    editable = [v for v in versions if v["attributes"]["appStoreState"] in EDITABLE]
    if not editable and any_version:
        editable = versions
    if not editable:
        raise SystemExit("no editable App Store version")
    v = editable[0]
    return {"info": info["id"],
            "info_loc": asc.get(f"/appInfos/{info['id']}/appInfoLocalizations")["data"][0]["id"],
            "version": v["id"], "version_string": v["attributes"]["versionString"],
            "version_loc": asc.get(f"/appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"][0]["id"]}


def upload_screenshots(asc, version_loc):
    """6.7" set (APP_IPHONE_67, 1290x2796). Replaces whatever is there so the set
    always mirrors marketing/asc-screenshots/ in filename order."""
    files = sorted(p for p in SHOTS.glob("*.png"))
    if not files:
        print("    no screenshots in", SHOTS); return
    sets = asc.get(f"/appStoreVersionLocalizations/{version_loc}/appScreenshotSets")["data"]
    st = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67"), None)
    if not st:
        st = asc.post("/appScreenshotSets", {"data": {"type": "appScreenshotSets",
              "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
              "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": version_loc}}}}})["data"]
    existing = asc.get(f"/appScreenshotSets/{st['id']}/appScreenshots")["data"]
    have = {e["attributes"].get("fileName"): e for e in existing}
    if [e["attributes"].get("fileName") for e in existing] == [f.name for f in files] and all(
            (have[f.name]["attributes"].get("sourceFileChecksum") or "") == hashlib.md5(f.read_bytes()).hexdigest() for f in files):
        print(f"    screenshots already current ({len(files)})"); return
    for e in existing:
        asc.delete(f"/appScreenshots/{e['id']}")
    for f in files:
        data = f.read_bytes()
        res = asc.post("/appScreenshots", {"data": {"type": "appScreenshots",
               "attributes": {"fileName": f.name, "fileSize": len(data)},
               "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": st["id"]}}}}})["data"]
        for op in res["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]: op["offset"] + op["length"]]
            hdrs = {h["name"]: h["value"] for h in op["requestHeaders"]}
            r = requests.request(op["method"], op["url"], headers=hdrs, data=chunk, timeout=120)
            if r.status_code >= 400:
                raise SystemExit(f"upload chunk failed {r.status_code}: {r.text[:200]}")
        asc.patch(f"/appScreenshots/{res['id']}", {"data": {"type": "appScreenshots", "id": res["id"],
                  "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print("    uploaded", f.name)


def ensure_availability(asc, app_id):
    """Create the availability record if the app has none. Without it Apple shows
    the approved version as "removed from sale". Lives at /v2, not /v1."""
    r = asc.s.get(f"{HOST}/v1/apps/{app_id}/appAvailabilityV2", timeout=30)
    if r.status_code == 200 and r.json().get("data"):
        print("    availability already set"); return
    url, params, terr = f"{API}/territories", {"limit": 200}, []
    while url:
        j = asc._ok(asc.s.get(url, params=params, timeout=30)); params = None
        terr += [t["id"] for t in j["data"]]; url = j.get("links", {}).get("next")
    asc._ok(asc.s.post(f"{HOST}/v2/appAvailabilities", timeout=60, json={
        "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True},
                 "relationships": {"app": {"data": {"type": "apps", "id": app_id}},
                                   "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": f"${{{t}}}"} for t in terr]}}},
        "included": [{"type": "territoryAvailabilities", "id": f"${{{t}}}", "attributes": {"available": True},
                      "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for t in terr]}))
    print(f"    availability: {len(terr)} territories + new ones")


def availability_summary(asc, app_id):
    r = asc.s.get(f"{HOST}/v1/apps/{app_id}/appAvailabilityV2", timeout=30)
    if r.status_code != 200 or not r.json().get("data"):
        return "MISSING (shows as removed from sale)"
    url, params, rows = f"{HOST}/v2/appAvailabilities/{r.json()['data']['id']}/territoryAvailabilities", {"limit": 200}, []
    while url:
        j = asc._ok(asc.s.get(url, params=params, timeout=30)); params = None
        rows += j["data"]; url = j.get("links", {}).get("next")
    on = sum(1 for d in rows if d["attributes"].get("available"))
    return f"{on}/{len(rows)} territories on"


def attach_build(asc, app_id, version_id, wanted: str):
    """Point the version at one specific build number (never "newest": a fresh
    upload is invisible or PROCESSING for minutes and "newest VALID" is the
    previous one). Waits for processing to finish."""
    for _ in range(60):
        match = [b for b in asc.builds(app_id) if b["attributes"].get("version") == wanted]
        if match and match[0]["attributes"].get("processingState") == "VALID":
            asc.patch(f"/appStoreVersions/{version_id}/relationships/build", {"data": {"type": "builds", "id": match[0]["id"]}})
            print(f"    build {wanted} attached"); return
        state = match[0]["attributes"].get("processingState") if match else "not in ASC yet"
        print(f"    build {wanted}: {state}, waiting…"); time.sleep(30)
    raise SystemExit(f"build {wanted} never became VALID")


def apply(asc, cfg, build: str | None):
    assert len(SUBTITLE) <= 30 and len(KEYWORDS) <= 100 and len(PROMO) <= 170 and len(DESCRIPTION) <= 4000
    app_id = cfg["ASC_APP_ID"]; ids = resolve(asc, app_id)
    print(f"==> version {ids['version_string']}")
    # The logo, photos, menu and name belong to the restaurant, not the developer account.
    asc.patch(f"/apps/{app_id}", {"data": {"type": "apps", "id": app_id,
              "attributes": {"contentRightsDeclaration": "USES_THIRD_PARTY_CONTENT"}}})
    print("    content rights: uses third-party content")
    asc.patch(f"/appInfos/{ids['info']}", {"data": {"type": "appInfos", "id": ids["info"], "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": PRIMARY_CATEGORY}}}}})
    print(f"    category {PRIMARY_CATEGORY}")
    asc.patch(f"/appInfoLocalizations/{ids['info_loc']}", {"data": {"type": "appInfoLocalizations", "id": ids["info_loc"],
              "attributes": {"subtitle": SUBTITLE, "privacyPolicyUrl": PRIVACY}}})
    print("    subtitle + privacy policy URL")
    asc.patch(f"/appStoreVersionLocalizations/{ids['version_loc']}", {"data": {"type": "appStoreVersionLocalizations", "id": ids["version_loc"],
              "attributes": {"description": DESCRIPTION, "keywords": KEYWORDS, "promotionalText": PROMO,
                             "supportUrl": SUPPORT, "marketingUrl": SITE}}})
    print("    description, keywords, promo, URLs")
    asc.patch(f"/appStoreVersions/{ids['version']}", {"data": {"type": "appStoreVersions", "id": ids["version"],
              "attributes": {"copyright": COPYRIGHT, "usesIdfa": False, "releaseType": RELEASE_TYPE}}})
    print(f"    copyright, no IDFA, release {RELEASE_TYPE}")
    asc.patch(f"/ageRatingDeclarations/{ids['info']}", {"data": {"type": "ageRatingDeclarations", "id": ids["info"], "attributes": AGE_RATING}})
    print("    age rating (4+)")
    missing = [k for k in ("ASC_CONTACT_FIRST_NAME", "ASC_CONTACT_LAST_NAME", "ASC_CONTACT_PHONE", "ASC_CONTACT_EMAIL") if not cfg.get(k)]
    if missing:
        raise SystemExit("asc-config.env is missing: " + ", ".join(missing))
    detail = asc.get(f"/appStoreVersions/{ids['version']}/appStoreReviewDetail").get("data")
    attrs = {"contactFirstName": cfg["ASC_CONTACT_FIRST_NAME"], "contactLastName": cfg["ASC_CONTACT_LAST_NAME"],
             "contactPhone": cfg["ASC_CONTACT_PHONE"], "contactEmail": cfg["ASC_CONTACT_EMAIL"],
             "demoAccountRequired": False, "notes": REVIEW_NOTES}
    if detail:
        asc.patch(f"/appStoreReviewDetails/{detail['id']}", {"data": {"type": "appStoreReviewDetails", "id": detail["id"], "attributes": attrs}})
    else:
        asc.post("/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": attrs,
                 "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ids["version"]}}}}})
    print("    review contact + notes")
    # A schedule object can exist with a base territory and NO prices (Spendcap,
    # 2026-09-03: submission then fails APP_PRICING_REQUIRED). Check the prices.
    r = asc.s.get(f"{API}/appPriceSchedules/{app_id}/manualPrices", timeout=30)
    if r.status_code == 200 and r.json().get("data"):
        print("    price schedule already set")
    else:
        points = asc.get(f"/apps/{app_id}/appPricePoints", **{"filter[territory]": "USA", "limit": 200})["data"]
        free = next(p for p in points if float(p["attributes"]["customerPrice"]) == 0.0)
        asc.post("/appPriceSchedules", {"data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": {"type": "apps", "id": app_id}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "appPrices", "id": "${free}"}]}}},
            "included": [{"type": "appPrices", "id": "${free}", "attributes": {"startDate": None},
                          "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}]})
        print("    price: free (USA base)")
    ensure_availability(asc, app_id)
    upload_screenshots(asc, ids["version_loc"])
    if build:
        attach_build(asc, app_id, ids["version"], build)


def show(asc, cfg):
    ids = resolve(asc, cfg["ASC_APP_ID"], any_version=True)
    loc = asc.get(f"/appStoreVersionLocalizations/{ids['version_loc']}")["data"]["attributes"]
    il = asc.get(f"/appInfoLocalizations/{ids['info_loc']}")["data"]["attributes"]
    v = asc.get(f"/appStoreVersions/{ids['version']}")["data"]["attributes"]
    det = asc.get(f"/appStoreVersions/{ids['version']}/appStoreReviewDetail").get("data")
    b = asc.get(f"/appStoreVersions/{ids['version']}/build").get("data")
    sets = asc.get(f"/appStoreVersionLocalizations/{ids['version_loc']}/appScreenshotSets")["data"]
    n = sum(len(asc.get(f"/appScreenshotSets/{s['id']}/appScreenshots")["data"]) for s in sets)
    print(f"version {v['versionString']} {v['appStoreState']} release {v.get('releaseType')}\n  subtitle    {il.get('subtitle')}\n  privacy     {il.get('privacyPolicyUrl')}"
          f"\n  description {len(loc.get('description') or '')} chars\n  keywords    {loc.get('keywords')}\n  support     {loc.get('supportUrl')}"
          f"\n  copyright   {v.get('copyright')}\n  build       {b['attributes']['version'] if b else '(none)'}\n  review info {'set' if det else 'MISSING'}"
          f"\n  screenshots {n} in {len(sets)} set(s)\n  availability {availability_summary(asc, cfg['ASC_APP_ID'])}")


if __name__ == "__main__":
    cfg = load_config(); asc = ASC(cfg)
    if "--show" in sys.argv:
        show(asc, cfg)
    else:
        b = sys.argv[sys.argv.index("--build") + 1] if "--build" in sys.argv else None
        apply(asc, cfg, b)
