# --- Helm Provider for Vault ---

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

# --- Vault Namespace ---

resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"

    labels = {
      app       = "vault"
      managedby = "terraform"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

# --- Vault Helm Release ---

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_helm_version
  namespace  = kubernetes_namespace.vault.metadata[0].name

  set {
    name  = "server.ha.enabled"
    value = "true"
  }

  set {
    name  = "server.ha.replicas"
    value = var.vault_replicas
  }

  set {
    name  = "server.ha.raft.enabled"
    value = "true"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "server.resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "server.resources.limits.memory"
    value = "512Mi"
  }

  set {
    name  = "server.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "server.dataStorage.size"
    value = "10Gi"
  }

  set {
    name  = "server.auditStorage.enabled"
    value = "true"
  }

  set {
    name  = "server.auditStorage.size"
    value = "10Gi"
  }

  set {
    name  = "ui.enabled"
    value = "true"
  }

  set {
    name  = "ui.serviceType"
    value = "ClusterIP"
  }

  set {
    name  = "injector.enabled"
    value = "true"
  }

  depends_on = [aws_eks_node_group.main]
}
