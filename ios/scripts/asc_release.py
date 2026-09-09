#!/usr/bin/env python3
"""Release an approved version to the App Store.

The version is submitted with releaseType MANUAL (see asc_metadata.py), so
approval parks it in PENDING_DEVELOPER_RELEASE. This is the go-live click.

    python3 scripts/asc_release.py
"""
from __future__ import annotations
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from asc_metadata import ASC, load_config  # noqa: E402


def main() -> int:
    cfg = load_config(); asc = ASC(cfg)
    versions = asc.get(f"/apps/{cfg['ASC_APP_ID']}/appStoreVersions", limit=5)["data"]
    for v in versions:
        print(f"  {v['attributes']['versionString']}  {v['attributes']['appStoreState']}")
    ready = next((v for v in versions if v["attributes"]["appStoreState"] == "PENDING_DEVELOPER_RELEASE"), None)
    if not ready:
        raise SystemExit("no version is waiting for developer release")
    asc.post("/appStoreVersionReleaseRequests", {"data": {"type": "appStoreVersionReleaseRequests", "relationships": {
        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": ready["id"]}}}}})
    print(f"✅ release requested for {ready['attributes']['versionString']}; it goes live within a few hours")
    return 0


if __name__ == "__main__":
    sys.exit(main())
