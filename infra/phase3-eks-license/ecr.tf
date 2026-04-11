# --- ECR Repository for License Server ---
#
# WHY ECR over Docker Hub:
# - Same AWS network = fast pulls from EKS (no cross-internet transfer)
# - IAM-based auth = no separate Docker credentials to manage
# - Image scanning = automatic CVE detection on push
# - Lifecycle policies = auto-cleanup old images to save storage costs

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

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "secure-media-platform"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

locals {
  common_tags = {
    Project   = var.project_name
    Phase     = "phase3-eks-license"
    ManagedBy = "Terraform"
  }
}

resource "aws_ecr_repository" "license_server" {
  name = "${var.project_name}/license-server"

  # WHY IMMUTABLE: Once a tag is pushed (e.g., v1.2.3), it can't be
  # overwritten. This prevents "latest" tag hell where you can't tell
  # which code is actually running. Forces proper versioning.
  image_tag_mutability = "IMMUTABLE"

  # WHY scan on push: Catches CVEs immediately rather than discovering
  # them in production. ECR uses Clair under the hood.
  image_scanning_configuration {
    scan_on_push = true
  }

  # WHY encryption: Images may contain compiled secrets or sensitive
  # config baked in during CI. KMS encryption adds defense in depth.
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name = "License Server ECR"
  })
}

# WHY lifecycle policy: Without this, every CI push accumulates images
# forever. We keep the last 10 tagged images and expire untagged images
# (failed builds) after 1 day.
resource "aws_ecr_lifecycle_policy" "license_server" {
  repository = aws_ecr_repository.license_server.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only last 10 tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v"]
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "ecr_repository_url" {
  description = "URL of the license server ECR repository"
  value       = aws_ecr_repository.license_server.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the license server ECR repository"
  value       = aws_ecr_repository.license_server.arn
}
