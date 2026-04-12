#!/usr/bin/env python3
"""Generate a CloudFront signed URL for a private HLS manifest.

Uses a custom policy so the signed URL carries an explicit expiry the
player can't tamper with. The license server would normally do this
inline, but for end-to-end testing you often want to build one by hand
and paste it into the test player.

Usage:
    python3 scripts/sign-cloudfront-url.py \\
        --url "https://d1234.cloudfront.net/demo-movie-001/master.m3u8" \\
        --key-pair-id K2XXXXXXXXXXXX \\
        --private-key cf-private.pem \\
        --expires-in 3600

Prints the full signed URL to stdout.
"""

import argparse
import base64
import json
import sys
import time
from urllib.parse import quote

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding


# WHY CloudFront's own base64 variant: the URL-safe base64 alphabet
# differs from CloudFront's expectations (they use `-_~` instead of
# `+/=`). Shipping the wrong variant produces a "Signature mismatch"
# 403 with zero hints in the CloudFront logs. Cost me a day once.
def _cf_b64(data: bytes) -> str:
    return base64.b64encode(data).decode().replace("+", "-").replace("=", "_").replace("/", "~")


def build_policy(url: str, expires_at: int) -> str:
    policy = {
        "Statement": [
            {
                "Resource": url,
                "Condition": {"DateLessThan": {"AWS:EpochTime": expires_at}},
            }
        ]
    }
    # WHY compact separators: CloudFront hashes the exact bytes of the
    # policy string. Any whitespace difference between here and what
    # CloudFront recomputes invalidates the signature.
    return json.dumps(policy, separators=(",", ":"))


def sign(policy: str, private_key_path: str) -> str:
    with open(private_key_path, "rb") as f:
        key = serialization.load_pem_private_key(f.read(), password=None)
    # WHY PKCS1v15 + SHA1: CloudFront's documented signing algorithm.
    # It's legacy but mandated; RSA-PSS or SHA256 will not verify.
    signature = key.sign(policy.encode(), padding.PKCS1v15(), hashes.SHA1())
    return _cf_b64(signature)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--url", required=True, help="Full https URL to sign")
    p.add_argument("--key-pair-id", required=True, help="CloudFront public key ID (cloudfront_public_key_id output)")
    p.add_argument("--private-key", required=True, help="Path to cf-private.pem")
    p.add_argument("--expires-in", type=int, default=3600, help="Seconds until the URL expires (default 1h)")
    args = p.parse_args()

    expires_at = int(time.time()) + args.expires_in
    policy = build_policy(args.url, expires_at)
    signature = sign(policy, args.private_key)
    policy_b64 = _cf_b64(policy.encode())

    qs = f"Policy={quote(policy_b64)}&Signature={quote(signature)}&Key-Pair-Id={args.key_pair_id}"
    sep = "&" if "?" in args.url else "?"
    print(f"{args.url}{sep}{qs}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
