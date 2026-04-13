# SNS topic for license server alerts.
#
# WHY SNS in addition to Slack: Slack is where humans live, SNS is the
# durable fan-out point. Alertmanager posts to both — Slack for the
# oncall human, SNS for anything machine-consumable (PagerDuty bridge,
# email escalation, Lambda that opens a Jira ticket, etc.). Adding a
# new subscriber later is an SNS subscription, not an Alertmanager
# config change + redeploy.

resource "aws_sns_topic" "license_alerts" {
  name = "${var.project_name}-license-alerts-${var.environment}"

  # WHY KMS-encrypted: alert payloads contain the service name, latency
  # numbers, and runbook URLs. Not catastrophic if leaked, but SNS
  # topics are cheap to encrypt and it keeps the account-wide
  # compliance scan happy.
  kms_master_key_id = "alias/aws/sns"

  tags = merge(local.common_tags, {
    Component = "alerting"
  })
}

# WHY topic policy with explicit publisher ARN: Alertmanager runs in
# EKS and publishes via IRSA. This policy restricts `sns:Publish` to
# exactly that role — without it, the topic would either be wide open
# or rely on catch-all SNS defaults.
data "aws_iam_policy_document" "license_alerts_publish" {
  statement {
    sid    = "AllowAlertmanagerPublish"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.alertmanager_publisher.arn]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.license_alerts.arn]
  }
}

resource "aws_sns_topic_policy" "license_alerts" {
  arn    = aws_sns_topic.license_alerts.arn
  policy = data.aws_iam_policy_document.license_alerts_publish.json
}

# IRSA role Alertmanager assumes in-cluster to call sns:Publish.
# WHY IRSA instead of a static access key: static keys leak. IRSA ties
# the permission to a specific ServiceAccount in the monitoring
# namespace and rotates credentials automatically via STS.
data "aws_iam_openid_connect_provider" "eks" {
  # phase3 created the OIDC provider; we only need its ARN here.
  # If phase3's provider URL changes, this lookup fails loudly.
  url = var.eks_oidc_provider_url
}

data "aws_iam_policy_document" "alertmanager_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      # Must match the ServiceAccount the Alertmanager Helm chart uses.
      # kube-prometheus-stack default is
      # `system:serviceaccount:monitoring:kube-prometheus-stack-alertmanager`.
      values = [
        "system:serviceaccount:${var.alertmanager_namespace}:${var.alertmanager_service_account}",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "alertmanager_publisher" {
  name               = "${var.project_name}-alertmanager-publisher-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.alertmanager_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "alertmanager_publisher" {
  name = "publish-license-alerts"
  role = aws_iam_role.alertmanager_publisher.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.license_alerts.arn
      },
    ]
  })
}
