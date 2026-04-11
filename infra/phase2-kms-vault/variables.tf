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

variable "key_rotation_days" {
  description = "Number of days between automatic KMS key rotations"
  type        = number
  default     = 365
}

variable "key_deletion_window" {
  description = "Number of days before a deleted KMS key is permanently removed"
  type        = number
  default     = 30
}
