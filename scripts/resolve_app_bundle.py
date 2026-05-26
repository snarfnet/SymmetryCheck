#!/usr/bin/env python3
import os

from asc_helpers import api_json, fail


APP_ID = os.environ["APP_ID"]


def main():
    app = api_json("GET", f"/apps/{APP_ID}")["data"]
    attrs = app.get("attributes", {})
    bundle_id = attrs.get("bundleId")
    name = attrs.get("name")
    if not bundle_id:
        raise RuntimeError(f"App {APP_ID} did not return a bundleId.")

    print(f"Resolved app: {name} ({APP_ID})")
    print(f"Resolved bundle ID: {bundle_id}")
    print(f"APP_BUNDLE_ID={bundle_id}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        fail(error)
