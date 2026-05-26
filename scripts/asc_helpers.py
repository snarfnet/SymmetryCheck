import base64
import json
import os
import sys
import time
import urllib.parse
from pathlib import Path

import jwt
import requests


BASE_URL = "https://api.appstoreconnect.apple.com/v1"
KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER_ID = os.environ["ASC_ISSUER_ID"]
P8_PATH = Path(os.environ.get("ASC_P8_PATH", "/tmp/asc_key.p8"))


def make_token():
    now = int(time.time())
    private_key = P8_PATH.read_text(encoding="utf-8")
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )


def headers():
    return {"Authorization": f"Bearer {make_token()}", "Content-Type": "application/json"}


def api(method, path, **kwargs):
    if path.startswith("/v1/") or path.startswith("/v2/") or path.startswith("/v3/"):
        url = f"https://api.appstoreconnect.apple.com{path}"
    else:
        url = f"{BASE_URL}{path}"
    last_response = None
    for _ in range(6):
        last_response = requests.request(
            method,
            url,
            headers=headers(),
            timeout=120,
            **kwargs,
        )
        if last_response.status_code not in (401, 429, 500, 502, 503, 504):
            return last_response
        time.sleep(20)
    return last_response


def api_json(method, path, **kwargs):
    response = api(method, path, **kwargs)
    try:
        body = response.json()
    except Exception:
        body = {}
    if response.status_code not in (200, 201, 204):
        raise RuntimeError(f"{method} {path} failed {response.status_code}: {response.text[:800]}")
    return body


def first(path, label):
    data = api_json("GET", path).get("data", [])
    if not data:
        raise RuntimeError(f"No {label} found for {path}")
    return data[0]


def query(params):
    return urllib.parse.urlencode(params)


def decode_profile(content):
    return base64.b64decode(content)


def fail(error):
    print(str(error), file=sys.stderr)
    sys.exit(1)


def json_body(payload):
    return json.dumps(payload, ensure_ascii=False)
