output "raw_bucket_id" {
  description = "ID of the raw media S3 bucket"
  value       = aws_s3_bucket.raw_media.id
}

output "raw_bucket_arn" {
  description = "ARN of the raw media S3 bucket"
  value       = aws_s3_bucket.raw_media.arn
}

output "encrypted_bucket_id" {
  description = "ID of the encrypted media S3 bucket"
  value       = aws_s3_bucket.encrypted_media.id
}

output "encrypted_bucket_arn" {
  description = "ARN of the encrypted media S3 bucket"
  value       = aws_s3_bucket.encrypted_media.arn
}
