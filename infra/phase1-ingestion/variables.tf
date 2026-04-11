variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "secure-media-platform"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "raw_bucket_name" {
  description = "Name of the S3 bucket for raw uploaded media"
  type        = string
  default     = "smp-raw-media"
}

variable "encrypted_bucket_name" {
  description = "Name of the S3 bucket for encrypted HLS output"
  type        = string
  default     = "smp-encrypted-media"
}
