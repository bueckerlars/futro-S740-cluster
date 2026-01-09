# Cloudflared Tunnel Deployment
# Deploys cloudflared to create a tunnel to Cloudflare
# The tunnel routes traffic from Cloudflare to Traefik

resource "kubernetes_deployment" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = "default"
    labels = {
      app = "cloudflared"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "cloudflared"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }

      spec {
        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:latest"

          args = [
            "tunnel",
            "--no-autoupdate",
            "run"
          ]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.cloudflare_tunnel_token.metadata[0].name
                key  = "TUNNEL_TOKEN"
              }
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster,
    kubernetes_secret.cloudflare_tunnel_token
  ]
}

