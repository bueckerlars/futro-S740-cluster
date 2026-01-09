# Vaultwarden Service Module
# Deploys Vaultwarden as a Kubernetes Deployment with persistent storage

# Create vaultwarden namespace
resource "kubernetes_namespace" "vaultwarden" {
  metadata {
    name = var.namespace
  }
}

# PersistentVolumeClaim for Vaultwarden data
resource "kubernetes_persistent_volume_claim_v1" "vaultwarden_data" {
  metadata {
    name      = "vaultwarden-data"
    namespace = kubernetes_namespace.vaultwarden.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.storage_size
      }
    }
    # Uses default storage class (nfs)
  }
}

# Vaultwarden Deployment
resource "kubernetes_deployment_v1" "vaultwarden" {
  metadata {
    name      = "vaultwarden"
    namespace = kubernetes_namespace.vaultwarden.metadata[0].name
    labels = {
      app = "vaultwarden"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "vaultwarden"
      }
    }

    template {
      metadata {
        labels = {
          app = "vaultwarden"
        }
      }

      spec {
        container {
          name  = "vaultwarden"
          image = "vaultwarden/server:latest"

          port {
            container_port = 80
            name           = "http"
          }

          env {
            name  = "SIGNUPS_ALLOWED"
            value = "false"
          }

          env {
            name  = "ADMIN_TOKEN"
            value = var.admin_token
          }

          env {
            name  = "DOMAIN"
            value = "https://${var.domain}"
          }

          env {
            name  = "LOG_LEVEL"
            value = "warn"
          }

          env {
            name  = "DATABASE_URL"
            value = "/data/db.sqlite3"
          }

          env {
            name  = "WEB_VAULT_ENABLED"
            value = "true"
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.vaultwarden_data.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_persistent_volume_claim_v1.vaultwarden_data
  ]
}

# Vaultwarden Service
resource "kubernetes_service_v1" "vaultwarden" {
  metadata {
    name      = "vaultwarden"
    namespace = kubernetes_namespace.vaultwarden.metadata[0].name
    labels = {
      app = "vaultwarden"
    }
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = "vaultwarden"
    }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }

  depends_on = [
    kubernetes_deployment_v1.vaultwarden
  ]
}

# Wait for Vaultwarden service to be ready
resource "time_sleep" "wait_for_vaultwarden" {
  depends_on = [kubernetes_service_v1.vaultwarden]

  create_duration = "30s"
}

# HTTP Ingress for Vaultwarden (no TLS, works without certificates)
resource "kubernetes_ingress_v1" "vaultwarden_http" {
  metadata {
    name      = "vaultwarden-http"
    namespace = kubernetes_namespace.vaultwarden.metadata[0].name
    annotations = merge(
      {
        "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      },
      length(var.middlewares) > 0 ? {
        "traefik.ingress.kubernetes.io/router.middlewares" = join(",", [for m in var.middlewares : "${var.middleware_namespace}-${m}@kubernetescrd"])
      } : {}
    )
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = var.domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.vaultwarden.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.vaultwarden,
    time_sleep.wait_for_vaultwarden
  ]
}

# HTTPS Ingress for Vaultwarden (with TLS, requires certificates)
# Note: Must include 'web' entrypoint for ACME HTTP challenge to work
resource "kubernetes_ingress_v1" "vaultwarden" {
  metadata {
    name      = "vaultwarden"
    namespace = kubernetes_namespace.vaultwarden.metadata[0].name
    annotations = merge(
      {
        "traefik.ingress.kubernetes.io/router.entrypoints"      = "web,websecure"
        "traefik.ingress.kubernetes.io/router.tls.certresolver" = var.letsencrypt_certresolver
      },
      length(var.middlewares) > 0 ? {
        "traefik.ingress.kubernetes.io/router.middlewares" = join(",", [for m in var.middlewares : "${var.middleware_namespace}-${m}@kubernetescrd"])
      } : {}
    )
  }

  spec {
    ingress_class_name = "traefik"
    tls {
      hosts = [var.domain]
      # secret_name removed - Traefik creates the secret automatically with the CertResolver
    }
    rule {
      host = var.domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.vaultwarden.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.vaultwarden,
    time_sleep.wait_for_vaultwarden
  ]
}

