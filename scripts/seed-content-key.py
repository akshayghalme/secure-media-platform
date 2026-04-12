#!/usr/bin/env python3
"""Seed a test content key into KMS + Vault so the license server has
something to return.

Flow: generate a random AES-128 key → encrypt it with the project KMS
key → base64 the ciphertext → write it to Vault KV-v2 at
`secret/data/content-keys/<content_id>`.

This mirrors what a real ingestion pipeline would do in phase 2 key
rotation; we do it manually for bootstrap / demo purposes.

Usage:
    export VAULT_ADDR=http://localhost:8200
    export VAULT_TOKEN=root           # dev-mode Vault only
    export KMS_KEY_ALIAS=alias/secure-media-platform-content-key-dev
    export AWS_REGION=ap-south-1
    python3 scripts/seed-content-key.py demo-movie-001

The script prints the raw AES key in hex so you can plug it directly
into an HLS manifest's EXT-X-KEY for local testing.
"""

import base64
import os
import secrets
import sys
from datetime import datetime, timezone

import boto3
import httpx


def main() -> int:
    # WHY an optional --key flag: the demo key-flow requires the SAME
    # AES key in Vault and in the Lambda's HLS_AES_KEY env var. The
    # deploy-demo-key.sh wrapper generates one key, feeds it to
    # terraform, then calls this script with --key so both sides match.
    # Without --key we generate a random one (useful for testing the
    # seed path in isolation).
    args = sys.argv[1:]
    explicit_key_hex: str | None = None
    positional: list[str] = []
    i = 0
    while i < len(args):
        if args[i] == "--key" and i + 1 < len(args):
            explicit_key_hex = args[i + 1]
            i += 2
        else:
            positional.append(args[i])
            i += 1
    if len(positional) != 1:
        print("usage: seed-content-key.py [--key <hex>] <content_id>", file=sys.stderr)
        return 2
    content_id = positional[0]

    vault_addr = os.environ["VAULT_ADDR"]
    vault_token = os.environ["VAULT_TOKEN"]
    kms_alias = os.environ.get("KMS_KEY_ALIAS", "alias/secure-media-platform-content-key-dev")
    region = os.environ.get("AWS_REGION", "ap-south-1")

    # WHY 16 bytes: AES-128 matches what MediaConvert's HLS encryption
    # uses by default. AES-256 works too but the HLS spec only formally
    # covers 128-bit; some players choke on 256.
    if explicit_key_hex:
        if len(explicit_key_hex) != 32:
            print(f"--key must be 32 hex chars (16 bytes), got {len(explicit_key_hex)}", file=sys.stderr)
            return 2
        key_bytes = bytes.fromhex(explicit_key_hex)
        print(f"using provided AES-128 key: {key_bytes.hex()}")
    else:
        key_bytes = secrets.token_bytes(16)
        print(f"generated AES-128 key: {key_bytes.hex()}")

    # WHY KMS encrypt: the plaintext key never gets persisted. Vault
    # stores only the KMS ciphertext, so even a full Vault compromise
    # doesn't leak content keys without also breaching KMS.
    kms = boto3.client("kms", region_name=region)
    enc = kms.encrypt(KeyId=kms_alias, Plaintext=key_bytes)
    encrypted_b64 = base64.b64encode(enc["CiphertextBlob"]).decode()
    key_id = enc["KeyId"].split("/")[-1]

    # WHY KV v2 path shape: Vault KV v2 stores data under
    # `<mount>/data/<path>` and reads come back nested as
    # `data.data.<field>`. The license server's vault_client.py already
    # expects this shape; we just have to match it on write.
    url = f"{vault_addr}/v1/secret/data/content-keys/{content_id}"
    payload = {
        "data": {
            "encrypted_key": encrypted_b64,
            "key_id": key_id,
            "rotated_at": datetime.now(timezone.utc).isoformat(),
        }
    }
    r = httpx.post(url, headers={"X-Vault-Token": vault_token}, json=payload, timeout=10)
    r.raise_for_status()

    print(f"wrote Vault secret at content-keys/{content_id}")
    print("")
    print("next: use this hex key when encrypting HLS segments, or let")
    print("MediaConvert generate its own and rewrite Vault to match.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
