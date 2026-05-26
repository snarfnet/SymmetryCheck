#!/usr/bin/env python3
import base64
import hashlib
import os
from pathlib import Path

from asc_helpers import api, api_json, decode_profile, fail, query


BUNDLE_ID = os.environ.get("APP_BUNDLE_ID", "com.tokyonasu.morimoriphotomaker")
PROFILE_NAME = os.environ.get("PROFILE_NAME", "MorimoriPhotoMaker App Store")
PROFILE_PATH = Path.home() / "Library/MobileDevice/Provisioning Profiles/MorimoriPhotoMaker_App_Store.mobileprovision"
CERT_SHA1 = os.environ.get("IOS_DISTRIBUTION_CERT_SHA1", "").replace(":", "").upper()
CERTIFICATE_ID = os.environ.get("ASC_CERTIFICATE_ID", "")


def cert_sha1(certificate):
    content = certificate.get("attributes", {}).get("certificateContent")
    if not content:
        detail = api_json("GET", f"/certificates/{certificate['id']}").get("data", certificate)
        content = detail.get("attributes", {}).get("certificateContent")
    if not content:
        return ""
    return hashlib.sha1(base64.b64decode(content)).hexdigest().upper()


def find_distribution_certificate():
    if CERTIFICATE_ID:
        return api_json("GET", f"/certificates/{CERTIFICATE_ID}")["data"]

    certificates = []
    for cert_type in ("IOS_DISTRIBUTION", "DISTRIBUTION"):
        certificates.extend(api_json("GET", f"/certificates?filter[certificateType]={cert_type}&limit=20").get("data", []))
    if not certificates:
        certificates = api_json("GET", "/certificates?limit=20").get("data", [])
    if not certificates:
        raise RuntimeError("No distribution certificate found.")
    if CERT_SHA1:
        for certificate in certificates:
            if cert_sha1(certificate) == CERT_SHA1:
                return certificate
        print(f"Warning: no App Store Connect certificate matched installed certificate {CERT_SHA1}.")
        print("Using the first available distribution certificate.")
    return certificates[0]


def profile_certificate_ids(profile_id):
    data = api_json("GET", f"/profiles/{profile_id}/relationships/certificates?limit=10").get("data", [])
    return {item["id"] for item in data}


def find_or_create_profile(bundle_id, certificate_id):
    existing = api_json("GET", f"/profiles?{query({'filter[name]': PROFILE_NAME, 'limit': '200'})}").get("data", [])
    for profile in existing:
        attrs = profile.get("attributes", {})
        if attrs.get("profileState") != "ACTIVE":
            continue
        if certificate_id in profile_certificate_ids(profile["id"]):
            detail = api_json("GET", f"/profiles/{profile['id']}").get("data", profile)
            if detail.get("attributes", {}).get("profileContent"):
                return detail

    for profile in existing:
        response = api("DELETE", f"/profiles/{profile['id']}")
        print(f"Deleted stale profile {profile['id']}: {response.status_code}")

    payload = {
        "data": {
            "type": "profiles",
            "attributes": {"name": PROFILE_NAME, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_id}},
                "certificates": {"data": [{"type": "certificates", "id": certificate_id}]},
            },
        }
    }
    return api_json("POST", "/profiles", json=payload)["data"]


def main():
    data = api_json("GET", f"/bundleIds?filter[identifier]={BUNDLE_ID}&limit=1").get("data", [])
    if not data:
        raise RuntimeError(f"Bundle ID does not exist: {BUNDLE_ID}")

    certificate = find_distribution_certificate()
    profile = find_or_create_profile(data[0]["id"], certificate["id"])
    content = profile.get("attributes", {}).get("profileContent")
    if not content:
        profile = api_json("GET", f"/profiles/{profile['id']}")["data"]
        content = profile.get("attributes", {}).get("profileContent")
    if not content:
        raise RuntimeError("Provisioning profile was created, but profileContent was empty.")

    PROFILE_PATH.parent.mkdir(parents=True, exist_ok=True)
    PROFILE_PATH.write_bytes(decode_profile(content))
    print(PROFILE_PATH)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        fail(error)
