output "content_key_id" {
  description = "ID of the content encryption KMS key"
  value       = aws_kms_key.content_encryption.key_id
}

output "content_key_arn" {
  description = "ARN of the content encryption KMS key"
  value       = aws_kms_key.content_encryption.arn
}

output "content_key_alias" {
  description = "Alias of the content encryption KMS key"
  value       = aws_kms_alias.content_encryption.name
}

output "s3_key_id" {
  description = "ID of the S3 encryption KMS key"
  value       = aws_kms_key.s3_encryption.key_id
}

output "s3_key_arn" {
  description = "ARN of the S3 encryption KMS key"
  value       = aws_kms_key.s3_encryption.arn
}
