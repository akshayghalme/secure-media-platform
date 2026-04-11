# --- DynamoDB Table: content_id → key mapping ---
# Maps each content piece to its encryption key metadata

resource "aws_dynamodb_table" "content_keys" {
  name         = "${var.project_name}-content-keys-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "content_id"

  attribute {
    name = "content_id"
    type = "S"
  }

  attribute {
    name = "key_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "key_id-index"
    hash_key        = "key_id"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "created_at-index"
    hash_key        = "created_at"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.content_encryption.arn
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = merge(local.common_tags, {
    Name = "Content Keys Mapping"
  })
}
