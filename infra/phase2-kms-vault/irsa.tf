# IRSA foundation — the OIDC identity provider.
#
# WHY this exists: EKS clusters expose an OIDC issuer URL but that URL
# is NOT automatically trusted by IAM. You have to explicitly create an
# aws_iam_openid_connect_provider pointing at the cluster's issuer
# before IAM will accept OIDC-signed JWTs from pods. Without this
# resource, every IRSA-annotated ServiceAccount fails silently with
# "Not authorized to perform sts:AssumeRoleWithWebIdentity".
#
# This is a one-time, cluster-wide resource. Every phase 3/4 module
# that wants to grant IAM to a pod will reference it by ARN.

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  # WHY this exact client_id: AWS requires "sts.amazonaws.com" as the
  # audience for IRSA. Hardcoded, not configurable.
  client_id_list = ["sts.amazonaws.com"]

  # WHY the thumbprint from tls_certificate: the OIDC spec requires a
  # thumbprint of the TLS cert chain so AWS can pin the issuer. If the
  # cert rotates, this resource needs a replace — acceptable tradeoff
  # for the security guarantee.
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  url = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-eks-oidc-${var.environment}"
  })
}
