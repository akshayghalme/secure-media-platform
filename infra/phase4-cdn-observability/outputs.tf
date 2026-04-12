output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.media.id
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain (use as playback base URL)"
  value       = aws_cloudfront_distribution.media.domain_name
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.media.arn
}

# WHY expose this: the license server needs the key pair ID to include in
# the Key-Pair-Id query param of signed URLs. CloudFront matches that ID
# against the public key in the trusted key group to pick a verifier.
output "cloudfront_public_key_id" {
  description = "ID of the CloudFront public key used for signed URL verification"
  value       = aws_cloudfront_public_key.signer.id
}

output "key_group_id" {
  description = "CloudFront key group ID"
  value       = aws_cloudfront_key_group.signers.id
}

output "oac_id" {
  description = "Origin Access Control ID"
  value       = aws_cloudfront_origin_access_control.encrypted_media.id
}
