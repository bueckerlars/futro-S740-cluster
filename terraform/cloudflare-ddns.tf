# Cloudflare DDNS Updater (DNS-only)
# Keeps A/AAAA records updated with the current public IPv4/IPv6 addresses.

resource "kubernetes_deployment" "cloudflare_ddns" {
  metadata {
    name      = "cloudflare-ddns"
    namespace = "kube-system"
    labels = {
      app = "cloudflare-ddns"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "cloudflare-ddns"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflare-ddns"
        }
      }

      spec {
        container {
          name  = "cloudflare-ddns"
          image = "favonia/cloudflare-ddns:latest"

          env {
            name = "CLOUDFLARE_API_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.cloudflare_api_token.metadata[0].name
                key  = "CLOUDFLARE_DNS_API_TOKEN"
              }
            }
          }

          env {
            name  = "DOMAINS"
            value = local.domains_csv
          }

          env {
            name  = "PROXIED"
            value = "false"
          }

          # Auto TTL in Cloudflare (1 == "automatic")
          env {
            name  = "TTL"
            value = "1"
          }

          # Detect public IPv4/IPv6 addresses via Cloudflare endpoints.
          env {
            name  = "IP4_PROVIDER"
            value = "cloudflare.trace"
          }

          env {
            name  = "IP6_PROVIDER"
            value = var.ddns_enable_ipv6 ? "cloudflare.trace" : "none"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster,
    kubernetes_secret.cloudflare_api_token
  ]
}

