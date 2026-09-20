#!/usr/bin/env python3
# Minimal App Store Connect API client — no third-party deps.
# Mints an ES256 JWT via the openssl CLI, then GETs an endpoint.
#
#   python3 BuildScripts/asc.py <v1-path>          e.g. ciProducts
#   python3 BuildScripts/asc.py ciProducts/<id>/buildRuns
#
# Credentials come from 1Password (Development/tmpdisk) by default;
# override with env: ASC_P8_FILE, ASC_KEY_ID, ASC_ISSUER.

import base64, json, os, subprocess, sys, tempfile, time, urllib.request

def op_read(ref):
    return subprocess.run(["op", "read", "op://Development/tmpdisk/" + ref],
                          capture_output=True, text=True, check=True).stdout.strip()

def b64url(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

def der_to_raw(der):
    # ECDSA DER sig: 30 <len> 02 <rlen> <r> 02 <slen> <s>  ->  r||s, 32 bytes each
    i = 2 if der[1] < 0x80 else 3
    rlen = der[i + 1]; r = der[i + 2:i + 2 + rlen]; i += 2 + rlen
    slen = der[i + 1]; s = der[i + 2:i + 2 + slen]
    return r.lstrip(b"\0").rjust(32, b"\0") + s.lstrip(b"\0").rjust(32, b"\0")

def mint_jwt(key_id, issuer, p8_path):
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = b64url(json.dumps({
        "iss": issuer, "aud": "appstoreconnect-v1",
        "iat": int(time.time()) - 60, "exp": int(time.time()) + 1140,
    }).encode())
    signing_input = (header + "." + payload).encode()
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", p8_path],
                         input=signing_input, capture_output=True, check=True).stdout
    return header + "." + payload + "." + b64url(der_to_raw(der))

def main():
    path = sys.argv[1]
    method = "GET"
    body = None
    if len(sys.argv) > 2 and sys.argv[2] == "--patch":
        method = "PATCH"
        body = sys.stdin.buffer.read()
    p8_file = os.environ.get("ASC_P8_FILE")
    key_id = os.environ.get("ASC_KEY_ID") or op_read("credential")
    issuer = os.environ.get("ASC_ISSUER") or op_read("username")
    tmp = None
    if not p8_file:
        tmp = tempfile.NamedTemporaryFile(prefix="asckey", suffix=".p8", delete=False)
        tmp.write(op_read("AuthKey_MX9U3D5TVW.p8").encode()); tmp.close()
        os.chmod(tmp.name, 0o600)
        p8_file = tmp.name
    try:
        jwt = mint_jwt(key_id, issuer, p8_file)
        req = urllib.request.Request(
            "https://api.appstoreconnect.apple.com/v1/" + path.lstrip("/"),
            data=body, method=method,
            headers={"Authorization": "Bearer " + jwt,
                     "Content-Type": "application/json"})
        with urllib.request.urlopen(req) as r:
            json.dump(json.load(r), sys.stdout, indent=2)
            print()
    finally:
        if tmp:
            os.unlink(tmp.name)

main()
