terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    # WHY tls provider: needed by irsa.tf to read the EKS OIDC issuer's
    # certificate and compute the SHA1 thumbprint that IAM requires
    # when registering the OIDC provider.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project   = var.project_name
    Phase     = "phase2-kms-vault"
    ManagedBy = "Terraform"
  }
}

data "aws_caller_identity" "current" {}

# --- Content Encryption KMS Key ---
# Used to encrypt/decrypt per-content HLS keys stored in Vault/DynamoDB

resource "aws_kms_key" "content_encryption" {
  description             = "Encrypts content-specific HLS decryption keys"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = true
  rotation_period_in_days = var.key_rotation_days

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowKeyAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEncryptDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "Content Encryption Key"
  })
}

resource "aws_kms_alias" "content_encryption" {
  name          = "alias/${var.project_name}-content-key-${var.environment}"
  target_key_id = aws_kms_key.content_encryption.key_id
}

# --- S3 Bucket Encryption KMS Key ---
# Dedicated key for S3 server-side encryption of media buckets

resource "aws_kms_key" "s3_encryption" {
  description             = "S3 server-side encryption for media buckets"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = true
  rotation_period_in_days = var.key_rotation_days

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowS3Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "S3 Encryption Key"
  })
}

resource "aws_kms_alias" "s3_encryption" {
  name          = "alias/${var.project_name}-s3-key-${var.environment}"
  target_key_id = aws_kms_key.s3_encryption.key_id
}
