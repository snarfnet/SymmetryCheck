#!/usr/bin/env python3
import base64
import hashlib
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from asc_helpers import api, api_json, fail, json_body


KEYCHAIN = os.environ.get("BUILD_KEYCHAIN", "build.keychain")
REPLACE_DISTRIBUTION_CERTIFICATE = os.environ.get("REPLACE_DISTRIBUTION_CERTIFICATE", "") == "1"
WORK_DIR = Path("/tmp/morimori-photo-maker-signing")
KEY_PATH = WORK_DIR / "distribution.key"
CSR_PATH = WORK_DIR / "distribution.csr"
CERT_PATH = WORK_DIR / "distribution.cer"
INVALID_SERIALS = {
    "797262360B421323CA2A52F022C3F0BF",
}
CI_CERT_MARKERS = ("morimoriphotomaker", "morimori photo maker")


def run(args):
    print("+", " ".join(str(arg) for arg in args), flush=True)
    subprocess.run(args, check=True)


def generate_csr():
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    run(["openssl", "genrsa", "-out", str(KEY_PATH), "2048"])
    run(
        [
            "openssl",
            "req",
            "-new",
            "-key",
            str(KEY_PATH),
            "-out",
            str(CSR_PATH),
            "-subj",
            "/CN=MorimoriPhotoMaker CI Distribution/O=TokyoNasu/C=JP",
        ]
    )


def certificate_lists():
    seen = set()
    certificates = []
    for cert_type in ("DISTRIBUTION", "IOS_DISTRIBUTION"):
        data = api_json("GET", f"/certificates?filter[certificateType]={cert_type}&limit=200").get("data", [])
        for certificate in data:
            if certificate["id"] not in seen:
                seen.add(certificate["id"])
                certificates.append(certificate)
    if not certificates:
        for certificate in api_json("GET", "/certificates?limit=200").get("data", []):
            if certificate["id"] not in seen:
                certificates.append(certificate)
    return certificates


def parse_expiration(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def delete_known_invalid_certificates():
    now = datetime.now(timezone.utc)
    deleted = 0
    certificates = certificate_lists()
    print(f"Found {len(certificates)} distribution certificate(s) to inspect.")
    for certificate in certificates:
        attrs = certificate.get("attributes", {})
        serial = (attrs.get("serialNumber") or "").replace(":", "").upper()
        expiration = parse_expiration(attrs.get("expirationDate"))
        names = " ".join(str(attrs.get(key) or "") for key in ("name", "displayName", "commonName")).lower()
        is_morimori_ci_cert = any(marker in names for marker in CI_CERT_MARKERS)
        should_delete = (
            REPLACE_DISTRIBUTION_CERTIFICATE
            or serial in INVALID_SERIALS
            or is_morimori_ci_cert
            or (expiration is not None and expiration < now)
        )
        if not should_delete:
            continue
        response = api("DELETE", f"/certificates/{certificate['id']}")
        print(
            f"Deleted stale distribution certificate {certificate['id']} "
            f"serial={serial or 'unknown'} status={response.status_code}"
        )
        if response.status_code in (200, 204):
            deleted += 1
    return deleted


def create_certificate_once(certificate_type):
    csr_content = CSR_PATH.read_text(encoding="utf-8")
    payload = {
        "data": {
            "type": "certificates",
            "attributes": {
                "certificateType": certificate_type,
                "csrContent": csr_content,
            },
        }
    }
    return api_json("POST", "/certificates", data=json_body(payload))["data"]


def should_clear_stale_certificates(error):
    text = str(error).lower()
    return (
        "maximum" in text
        or "max" in text
        or "limit" in text
        or "reached" in text
        or "already have a current" in text
        or "pending certificate request" in text
    )


def create_certificate():
    last_error = None
    cleaned = False
    for attempt in range(2):
        for certificate_type in ("DISTRIBUTION", "IOS_DISTRIBUTION"):
            try:
                certificate = create_certificate_once(certificate_type)
                print(f"Created certificate: {certificate['id']} ({certificate_type})")
                return certificate
            except Exception as error:
                last_error = error
                print(f"Certificate create failed for {certificate_type}: {error}")
        if not cleaned and last_error and should_clear_stale_certificates(last_error):
            cleaned = True
            deleted = delete_known_invalid_certificates()
            if deleted:
                print(f"Retrying certificate creation after deleting {deleted} stale certificate(s).")
                continue
        break
    raise RuntimeError(last_error)


def import_certificate(certificate):
    content = certificate.get("attributes", {}).get("certificateContent")
    if not content:
        raise RuntimeError("Created certificate did not include certificateContent.")

    CERT_PATH.write_bytes(base64.b64decode(content))
    run(["security", "import", str(KEY_PATH), "-k", KEYCHAIN, "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"])
    run(["security", "import", str(CERT_PATH), "-k", KEYCHAIN, "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"])
    run(
        [
            "security",
            "set-key-partition-list",
            "-S",
            "apple-tool:,apple:",
            "-s",
            "-k",
            os.environ["KEYCHAIN_PASSWORD"],
            KEYCHAIN,
        ]
    )

    sha1 = hashlib.sha1(CERT_PATH.read_bytes()).hexdigest().upper()
    print(f"IOS_DISTRIBUTION_CERT_SHA1={sha1}")
    print(f"ASC_CERTIFICATE_ID={certificate['id']}")


def main():
    generate_csr()
    certificate = create_certificate()
    import_certificate(certificate)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        fail(error)
