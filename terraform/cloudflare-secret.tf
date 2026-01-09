# Cloudflare API Token Secret
# Stores the Cloudflare API Token as a Kubernetes Secret (for potential future use with DNS Challenge)

resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "kube-system"
  }

  data = {
    "CLOUDFLARE_API_TOKEN" = var.cloudflare_api_token
  }

  type = "Opaque"

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster
  ]
}

# Cloudflare Tunnel Secret for cloudflared
# Stores the Cloudflare Tunnel Token as a Kubernetes Secret for cloudflared to use

resource "kubernetes_secret" "cloudflare_tunnel_token" {
  metadata {
    name      = "cloudflare-tunnel-token"
    namespace = "default"
  }

  data = {
    "TUNNEL_TOKEN" = var.cloudflare_tunnel_token
  }

  type = "Opaque"

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster
  ]
}

