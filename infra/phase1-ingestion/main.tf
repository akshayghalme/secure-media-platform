terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project   = var.project_name
    Phase     = "phase1-ingestion"
    ManagedBy = "Terraform"
  }
}

# --- Raw Media Bucket (upload target) ---

resource "aws_s3_bucket" "raw_media" {
  bucket = "${var.raw_bucket_name}-${var.environment}"

  tags = merge(local.common_tags, {
    Name = "Raw Media Bucket"
  })
}

resource "aws_s3_bucket_versioning" "raw_media" {
  bucket = aws_s3_bucket.raw_media.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw_media" {
  bucket = aws_s3_bucket.raw_media.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "raw_media" {
  bucket = aws_s3_bucket.raw_media.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "raw_media" {
  bucket = aws_s3_bucket.raw_media.id

  rule {
    id     = "archive-old-uploads"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

# --- Encrypted Media Bucket (HLS output) ---

resource "aws_s3_bucket" "encrypted_media" {
  bucket = "${var.encrypted_bucket_name}-${var.environment}"

  tags = merge(local.common_tags, {
    Name = "Encrypted Media Bucket"
  })
}

resource "aws_s3_bucket_versioning" "encrypted_media" {
  bucket = aws_s3_bucket.encrypted_media.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encrypted_media" {
  bucket = aws_s3_bucket.encrypted_media.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "encrypted_media" {
  bucket = aws_s3_bucket.encrypted_media.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "encrypted_media" {
  bucket = aws_s3_bucket.encrypted_media.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

# --- Bucket Policies ---

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "raw_media" {
  bucket = aws_s3_bucket.raw_media.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnencryptedUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.raw_media.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.raw_media.arn,
          "${aws_s3_bucket.raw_media.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "encrypted_media" {
  bucket = aws_s3_bucket.encrypted_media.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.encrypted_media.arn,
          "${aws_s3_bucket.encrypted_media.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
