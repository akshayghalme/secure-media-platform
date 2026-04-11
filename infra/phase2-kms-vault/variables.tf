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

# --- KMS ---

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

# --- VPC ---

variable "vpc_cidr" {
  description = "CIDR block for the EKS VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# --- EKS ---

variable "eks_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_desired" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_min" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_max" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 4
}

# --- Vault ---

variable "vault_helm_version" {
  description = "Vault Helm chart version"
  type        = string
  default     = "0.28.1"
}

variable "vault_replicas" {
  description = "Number of Vault server replicas (HA mode)"
  type        = number
  default     = 3
}
