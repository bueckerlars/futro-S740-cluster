# Traefik Configuration with Let's Encrypt
# Configures the built-in Traefik Ingress Controller in K3S to use Let's Encrypt for TLS certificates
# Uses HTTP Challenge (works with Cloudflare Tunnel as it provides public access)

resource "kubernetes_manifest" "traefik_helmchartconfig" {
  manifest = {
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "traefik"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = <<-EOT
additionalArguments:
  - "--certificatesresolvers.letsencrypt.acme.email=${var.letsencrypt_email}"
  - "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
  - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
EOT
    }
  }

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster
  ]
}

