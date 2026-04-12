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

# --- IRSA outputs ---
# WHY exposed: phase 3 needs the OIDC provider ARN to build the trust
# policy for the license-server IAM role, and the issuer URL (without
# the https:// prefix) to build the sub-claim condition key. These are
# cluster-scoped and stable for the life of the cluster.

output "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (used by IRSA trust policies)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "eks_oidc_issuer_host" {
  description = "OIDC issuer URL with https:// stripped — used as the sub-claim condition key"
  value       = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}
