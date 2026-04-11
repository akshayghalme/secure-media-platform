# Ansible — Key Rotation

Automatically rotates content encryption keys older than 30 days.

## Flow
1. Scans DynamoDB for keys with `created_at` older than 30 days
2. Generates a new data key via KMS (`generate-data-key`)
3. Stores the new encrypted key in Vault
4. Updates the DynamoDB mapping (preserves `previous_key_id` for rollback)

## Prerequisites
```bash
pip install ansible boto3
ansible-galaxy collection install -r requirements.yml
```

## Environment Variables
- `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- `VAULT_ADDR` — Vault server URL
- `VAULT_TOKEN` — Vault access token (use AppRole in production)

## Usage
```bash
cd ansible/key-rotation
ansible-playbook -i inventory.ini rotate-keys.yml
```

## Scheduling
Run via cron every 30 days:
```cron
0 2 1 * * cd /path/to/ansible/key-rotation && ansible-playbook -i inventory.ini rotate-keys.yml >> /var/log/key-rotation.log 2>&1
```

## Configuration
Edit `vars/main.yml` to change:
- `rotation_max_age_days` — key age threshold (default: 30)
- `dynamodb_table` — target DynamoDB table
- `kms_key_alias` — KMS key for generating new data keys
