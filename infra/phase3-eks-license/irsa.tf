# IRSA — IAM role for the license-server ServiceAccount.
#
# WHY this lives in phase 3 (not phase 2 next to the cluster): the role
# is scoped to exactly one workload, and its permissions track the
# license server's code changes, not the cluster's lifecycle. Putting
# it here means a "what does the license server need access to?"
# question is answered by one file, not by grepping across phases.
#
# This file is loosely coupled to phase 2 via data sources — no
# terraform_remote_state, no backend config sharing. If phase 2's
# cluster is renamed, `terraform plan` here breaks loudly at read time
# rather than drifting silently.

# --- Discover phase 2's OIDC provider + KMS key ---

data "aws_eks_cluster" "main" {
  name = "${var.project_name}-eks-${var.environment}"
}

data "aws_iam_openid_connect_provider" "eks" {
  # WHY look up by URL: phase 2's output is the provider ARN but data
  # sources filter by the OIDC issuer URL, which is stable regardless
  # of whether phase 2 runs before or after this module.
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

data "aws_kms_alias" "content_encryption" {
  name = "alias/${var.project_name}-content-key-${var.environment}"
}

locals {
  # WHY strip https://: the sub-claim condition key uses the host
  # portion only (e.g. `oidc.eks.ap-south-1.amazonaws.com/id/ABC123`).
  # Leaving the scheme in breaks the trust policy match with no error
  # at apply time — the first pod to assume the role gets 403.
  oidc_host = replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}

# --- Trust policy: only the license-server SA in the default namespace can assume ---

data "aws_iam_policy_document" "license_server_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    # WHY StringEquals on sub: this is the line that scopes the role to
    # ONE specific ServiceAccount. Without it, any pod in the cluster
    # with an OIDC-aware SDK could assume this role. The sub claim EKS
    # emits looks like:
    #   system:serviceaccount:<namespace>:<sa-name>
    # Hardcoding both here means accidentally deploying the chart to a
    # different namespace fails closed (no perms) instead of failing
    # open (silently works in prod with wrong scope).
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${var.license_server_namespace}:${var.license_server_sa_name}"]
    }

    # WHY the aud condition too: defense in depth. EKS always issues
    # tokens with aud=sts.amazonaws.com, but pinning it explicitly
    # prevents a future issuer misconfiguration from widening access.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "license_server" {
  name               = "${var.project_name}-license-server-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.license_server_assume.json

  tags = merge(local.common_tags, {
    Name = "License Server IRSA Role"
  })
}

# --- Permissions: only what the license server actually needs ---

data "aws_iam_policy_document" "license_server_perms" {
  # WHY Decrypt only (not Encrypt): the license server only ever
  # decrypts KMS-encrypted content keys fetched from Vault. Granting
  # Encrypt would let a compromised pod mint new keys — not catastrophic
  # but unnecessary reach.
  statement {
    sid       = "KmsDecryptContentKeys"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [data.aws_kms_alias.content_encryption.target_key_arn]
  }

  # WHY empty by design: the license server currently does NOT query
  # DynamoDB even though phase 2 creates the table. Adding a grant now
  # for hypothetical future use would violate least privilege. When
  # the code actually reads DynamoDB, add a second statement here.
}

resource "aws_iam_policy" "license_server" {
  name        = "${var.project_name}-license-server-${var.environment}"
  description = "KMS decrypt permissions for the license server pod"
  policy      = data.aws_iam_policy_document.license_server_perms.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "license_server" {
  role       = aws_iam_role.license_server.name
  policy_arn = aws_iam_policy.license_server.arn
}

output "license_server_role_arn" {
  description = "IAM role ARN to annotate on the license-server ServiceAccount (eks.amazonaws.com/role-arn)"
  value       = aws_iam_role.license_server.arn
}
