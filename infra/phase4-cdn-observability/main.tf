terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# WHY two provider blocks: CloudFront + ACM certificates for CloudFront MUST
# live in us-east-1 regardless of where the origin is. The default provider
# stays in the project's main region (ap-south-1); the aliased `us_east_1`
# provider is used only for resources CloudFront requires there.
provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

locals {
  common_tags = {
    Project   = var.project_name
    Phase     = "phase4-cdn-observability"
    ManagedBy = "Terraform"
  }
}

# WHY data source instead of remote_state: keeps phase4 loosely coupled to
# phase1's state backend. We look up the encrypted bucket by its known name
# (same construction rule phase1 uses). If phase1's naming changes, this
# breaks loudly at plan time rather than silently drifting.
data "aws_s3_bucket" "encrypted_media" {
  bucket = "${var.encrypted_bucket_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}
