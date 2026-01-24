# Tautulli Service Module
# Deploys Tautulli as a Kubernetes Deployment with persistent storage

# PersistentVolumeClaim for Tautulli config
resource "kubernetes_persistent_volume_claim_v1" "tautulli_config" {
  metadata {
    name      = "tautulli-config"
    namespace = var.namespace
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

# Tautulli Deployment
resource "kubernetes_deployment_v1" "tautulli" {
  metadata {
    name      = "tautulli"
    namespace = var.namespace
    labels = {
      app = "tautulli"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "tautulli"
      }
    }

    template {
      metadata {
        labels = {
          app = "tautulli"
        }
      }

      spec {
        container {
          name  = "tautulli"
          image = "linuxserver/tautulli:latest"

          port {
            container_port = 8181
            name           = "http"
          }

          env {
            name  = "PUID"
            value = tostring(var.puid)
          }

          env {
            name  = "PGID"
            value = tostring(var.pgid)
          }

          env {
            name  = "TZ"
            value = var.time_zone
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
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
          name = "config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.tautulli_config.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_persistent_volume_claim_v1.tautulli_config
  ]
}

# Tautulli Service
resource "kubernetes_service_v1" "tautulli" {
  metadata {
    name      = "tautulli"
    namespace = var.namespace
    labels = {
      app = "tautulli"
    }
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = "tautulli"
    }
    port {
      port        = 8181
      target_port = 8181
      protocol    = "TCP"
    }
  }

  depends_on = [
    kubernetes_deployment_v1.tautulli
  ]
}

# Wait for Tautulli service to be ready
resource "time_sleep" "wait_for_tautulli" {
  depends_on = [kubernetes_service_v1.tautulli]

  create_duration = "30s"
}

# HTTP Ingress for Tautulli (no TLS, works without certificates)
resource "kubernetes_ingress_v1" "tautulli_http" {
  metadata {
    name      = "tautulli-http"
    namespace = var.namespace
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
              name = kubernetes_service_v1.tautulli.metadata[0].name
              port {
                number = 8181
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.tautulli,
    time_sleep.wait_for_tautulli
  ]
}

# HTTPS Ingress for Tautulli (with TLS, requires certificates)
# Note: Must include 'web' entrypoint for ACME HTTP challenge to work
resource "kubernetes_ingress_v1" "tautulli" {
  metadata {
    name      = "tautulli"
    namespace = var.namespace
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
              name = kubernetes_service_v1.tautulli.metadata[0].name
              port {
                number = 8181
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.tautulli,
    time_sleep.wait_for_tautulli
  ]
}

# HTTPS Ingress for Tautulli local domain (with self-signed TLS certificate)
# Uses the default TLS store in kube-system namespace
resource "kubernetes_ingress_v1" "tautulli_local" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "tautulli-local"
    namespace = var.namespace
    annotations = merge(
      {
        "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
        # Use default TLS store (no certresolver, uses default certificate from TLSStore)
      },
      length(var.middlewares) > 0 ? {
        "traefik.ingress.kubernetes.io/router.middlewares" = join(",", [for m in var.middlewares : "${var.middleware_namespace}-${m}@kubernetescrd"])
      } : {}
    )
  }

  spec {
    ingress_class_name = "traefik"
    tls {
      hosts = ["tautulli.${var.local_domain}"]
      # No secret_name - uses default certificate from TLSStore
    }
    rule {
      host = "tautulli.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.tautulli.metadata[0].name
              port {
                number = 8181
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.tautulli,
    time_sleep.wait_for_tautulli
  ]
}

# HTTP Ingress for Tautulli local domain (redirects to HTTPS)
resource "kubernetes_ingress_v1" "tautulli_local_http" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "tautulli-local-http"
    namespace = var.namespace
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      "traefik.ingress.kubernetes.io/router.middlewares" = "default-https-redirect@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "tautulli.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.tautulli.metadata[0].name
              port {
                number = 8181
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.tautulli,
    time_sleep.wait_for_tautulli
  ]
}
