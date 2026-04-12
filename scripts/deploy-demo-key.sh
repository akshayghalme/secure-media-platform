#!/usr/bin/env bash
# deploy-demo-key.sh — generate ONE AES-128 key and make sure every
# component that touches it agrees on the value.
#
# WHY this script exists: the demo flow intentionally takes a shortcut.
# Phase 1's Lambda hands a static AES key to MediaConvert via an env var
# (HLS_AES_KEY), and phase 2's license server hands back the plaintext
# key from Vault. For playback to actually work, both sides must see
# the same bytes. Generating separately would give a key mismatch that
# surfaces as a generic "DECRYPT_ERROR" in hls.js an hour into debugging.
#
# This script generates one key and:
#   1. Updates the live Lambda's HLS_AES_KEY env var
#   2. Writes it into Vault at content-keys/<content_id> (KMS-encrypted)
#   3. Prints the key so you can plug it into terraform's tfvars for
#      future applies
#
# Production path (not this script): Lambda looks up the per-content
# key from Vault at invocation time, keyed on the S3 object prefix.
# Tracked as follow-up work.
#
# Usage:
#   export AWS_REGION=ap-south-1
#   export VAULT_ADDR=http://localhost:8200   # via kubectl port-forward
#   export VAULT_TOKEN=root                    # dev Vault only
#   export KMS_KEY_ALIAS=alias/secure-media-platform-content-key-dev
#   ./scripts/deploy-demo-key.sh demo-movie-001

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <content_id>" >&2
  exit 2
fi
CONTENT_ID="$1"

: "${AWS_REGION:?AWS_REGION required}"
: "${VAULT_ADDR:?VAULT_ADDR required (port-forward Vault first)}"
: "${VAULT_TOKEN:?VAULT_TOKEN required}"

PROJECT="${PROJECT_NAME:-secure-media-platform}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
LAMBDA_NAME="${PROJECT}-trigger-mediaconvert-${ENVIRONMENT}"

# WHY openssl rand -hex 16: 16 bytes = 128 bits, matches AES-128. hex
# encoding because that's what MediaConvert's StaticKeyValue expects
# (the docs call it "32-character hex string") and what the seed
# script's --key flag takes.
KEY_HEX="$(openssl rand -hex 16)"
echo "generated AES-128 key: $KEY_HEX"
echo ""

# --- 1. Push the key into the Lambda's env ---
# WHY read the current env first: update-function-configuration with
# --environment replaces the ENTIRE variables map. If we only passed
# HLS_AES_KEY, every other var (OUTPUT_BUCKET, MEDIACONVERT_ENDPOINT,
# etc.) would be wiped. We read, merge, and write back.
echo "→ updating Lambda $LAMBDA_NAME env"
CURRENT_ENV="$(aws lambda get-function-configuration \
  --function-name "$LAMBDA_NAME" \
  --region "$AWS_REGION" \
  --query 'Environment.Variables' \
  --output json)"

MERGED_ENV="$(echo "$CURRENT_ENV" | \
  HLS_AES_KEY="$KEY_HEX" python3 -c '
import json, os, sys
env = json.load(sys.stdin)
env["HLS_AES_KEY"] = os.environ["HLS_AES_KEY"]
print(json.dumps({"Variables": env}))
')"

aws lambda update-function-configuration \
  --function-name "$LAMBDA_NAME" \
  --region "$AWS_REGION" \
  --environment "$MERGED_ENV" \
  --output text --query 'LastUpdateStatus' >/dev/null

# WHY wait: update-function-configuration returns immediately but the
# config is still propagating. Subsequent invocations during the ~5s
# window run with stale env. Wait so the next S3 upload definitely
# sees the new key.
aws lambda wait function-updated \
  --function-name "$LAMBDA_NAME" \
  --region "$AWS_REGION"
echo "  lambda env updated"

# --- 2. Seed Vault with the same key ---
echo "→ seeding Vault content-keys/$CONTENT_ID"
python3 "$(dirname "$0")/seed-content-key.py" --key "$KEY_HEX" "$CONTENT_ID"

echo ""
echo "✓ all three components now agree on the key."
echo ""
echo "save this line somewhere so future terraform applies don't clobber it:"
echo "  export TF_VAR_hls_aes_key=$KEY_HEX"
