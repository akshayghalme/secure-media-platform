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

output "vpc_id" {
  description = "ID of the EKS VPC"
  value       = aws_vpc.eks.id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_ca" {
  description = "Certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "dynamodb_table_name" {
  description = "Name of the content keys DynamoDB table"
  value       = aws_dynamodb_table.content_keys.name
}

output "dynamodb_table_arn" {
  description = "ARN of the content keys DynamoDB table"
  value       = aws_dynamodb_table.content_keys.arn
}
