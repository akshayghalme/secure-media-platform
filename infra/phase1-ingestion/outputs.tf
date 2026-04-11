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

output "lambda_trigger_role_arn" {
  description = "ARN of the Lambda trigger execution role"
  value       = aws_iam_role.lambda_trigger.arn
}

output "mediaconvert_role_arn" {
  description = "ARN of the MediaConvert service role"
  value       = aws_iam_role.mediaconvert.arn
}

output "lambda_trigger_arn" {
  description = "ARN of the MediaConvert trigger Lambda function"
  value       = aws_lambda_function.trigger_mediaconvert.arn
}

output "mediaconvert_queue_arn" {
  description = "ARN of the MediaConvert ingestion queue"
  value       = aws_media_convert_queue.ingestion.arn
}
