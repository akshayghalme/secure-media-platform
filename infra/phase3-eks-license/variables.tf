# IRSA-related variables.
#
# WHY these live here and not in ecr.tf: ecr.tf defines the three
# baseline vars (project_name, environment, aws_region) inline with
# the ECR resource. As the module grows with IRSA + future pieces,
# cluster-scoped inputs belong in a dedicated variables.tf.

# WHY the namespace and SA name are variables: the IRSA trust policy's
# sub-claim condition pins to EXACTLY one namespace/SA combination.
# If the helm chart is ever deployed into a different namespace (e.g.
# `license` instead of `default`), the trust policy must be re-applied
# with the new values — otherwise pods fail to assume the role and the
# license server crash-loops on KMS AccessDenied. Keeping these as
# variables makes the coupling explicit in every `terraform plan`.

variable "license_server_namespace" {
  description = "Kubernetes namespace where the license server ServiceAccount lives (must match helm install -n)"
  type        = string
  default     = "default"
}

variable "license_server_sa_name" {
  description = "Name of the license server ServiceAccount (must match helm values.serviceAccount.name)"
  type        = string
  default     = "license-server"
}
