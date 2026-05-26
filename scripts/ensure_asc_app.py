#!/usr/bin/env python3
import os

from asc_helpers import api_json, fail, json_body, query


BUNDLE_ID = os.environ.get("APP_BUNDLE_ID", "com.tokyonasu.morimoriphotomaker")
BUNDLE_NAME = os.environ.get("BUNDLE_NAME", "MorimoriPhotoMaker")
APP_NAME = os.environ.get("APP_NAME", "盛り盛りフォトメーカー")
APP_SKU = os.environ.get("APP_SKU", "morimori-photo-maker-ios")


def ensure_bundle_id():
    body = api_json("GET", f"/bundleIds?{query({'filter[identifier]': BUNDLE_ID, 'limit': '1'})}")
    if body.get("data"):
        bundle = body["data"][0]
        print(f"Bundle ID already exists: {BUNDLE_ID} ({bundle['id']})")
        return bundle

    payload = {
        "data": {
            "type": "bundleIds",
            "attributes": {
                "identifier": BUNDLE_ID,
                "name": BUNDLE_NAME,
                "platform": "IOS",
            },
        }
    }
    bundle = api_json("POST", "/bundleIds", data=json_body(payload))["data"]
    print(f"Bundle ID created: {BUNDLE_ID} ({bundle['id']})")
    return bundle


def ensure_app(bundle):
    body = api_json("GET", f"/apps?{query({'filter[bundleId]': BUNDLE_ID, 'limit': '1'})}")
    if body.get("data"):
        app = body["data"][0]
        print(f"App already exists: {app['attributes'].get('name')} ({app['id']})")
        print(f"APP_ID={app['id']}")
        return app

    payload = {
        "data": {
            "type": "apps",
            "attributes": {
                "name": APP_NAME,
                "primaryLocale": "ja",
                "sku": APP_SKU,
            },
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}}
            },
        }
    }
    try:
        app = api_json("POST", "/apps", data=json_body(payload))["data"]
        print(f"App created: {app['attributes'].get('name')} ({app['id']})")
        print(f"APP_ID={app['id']}")
        return app
    except Exception as error:
        print(f"App Store Connect app was not created: {error}")
        print("Create the app manually in App Store Connect, then set GitHub Secret MORIMORI_PHOTO_MAKER_APP_ID.")
        return None


def main():
    bundle = ensure_bundle_id()
    ensure_app(bundle)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        fail(error)
