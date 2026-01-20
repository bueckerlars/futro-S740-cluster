# Cloudflare API Token Secret
# Stores the Cloudflare API Token and Email as a Kubernetes Secret for Traefik DNS-01 Challenge
# Traefik's Cloudflare DNS-01 provider expects CLOUDFLARE_DNS_API_TOKEN or CLOUDFLARE_ZONE_API_TOKEN.
# Additionally, CLOUDFLARE_EMAIL may be required by some Traefik versions.
# We reuse the same API token that is also used by the Terraform Cloudflare provider.

resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "kube-system"
  }

  data = {
    "CLOUDFLARE_DNS_API_TOKEN" = var.cloudflare_api_token
    "CLOUDFLARE_EMAIL"         = var.cloudflare_email != "" ? var.cloudflare_email : var.letsencrypt_email
  }

  type = "Opaque"

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster
  ]
}
