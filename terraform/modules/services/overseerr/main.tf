# Overseerr Service Module
# Deploys Overseerr as a Kubernetes Deployment with persistent storage

# PersistentVolumeClaim for Overseerr config
resource "kubernetes_persistent_volume_claim_v1" "overseerr_config" {
  metadata {
    name      = "overseerr-config"
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

# Overseerr Deployment
resource "kubernetes_deployment_v1" "overseerr" {
  metadata {
    name      = "overseerr"
    namespace = var.namespace
    labels = {
      app = "overseerr"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "overseerr"
      }
    }

    template {
      metadata {
        labels = {
          app = "overseerr"
        }
      }

      spec {
        container {
          name  = "overseerr"
          image = "linuxserver/overseerr:latest"

          port {
            container_port = 5055
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
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }
        }

        volume {
          name = "config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.overseerr_config.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_persistent_volume_claim_v1.overseerr_config
  ]
}

# Overseerr Service
resource "kubernetes_service_v1" "overseerr" {
  metadata {
    name      = "overseerr"
    namespace = var.namespace
    labels = {
      app = "overseerr"
    }
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = "overseerr"
    }
    port {
      port        = 5055
      target_port = 5055
      protocol    = "TCP"
    }
  }

  depends_on = [
    kubernetes_deployment_v1.overseerr
  ]
}

# Wait for Overseerr service to be ready
resource "time_sleep" "wait_for_overseerr" {
  depends_on = [kubernetes_service_v1.overseerr]

  create_duration = "30s"
}

# HTTP Ingress for Overseerr (no TLS, works without certificates)
resource "kubernetes_ingress_v1" "overseerr_http" {
  metadata {
    name      = "overseerr-http"
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
              name = kubernetes_service_v1.overseerr.metadata[0].name
              port {
                number = 5055
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.overseerr,
    time_sleep.wait_for_overseerr
  ]
}

# HTTPS Ingress for Overseerr (with TLS, requires certificates)
# Note: Must include 'web' entrypoint for ACME HTTP challenge to work
resource "kubernetes_ingress_v1" "overseerr" {
  metadata {
    name      = "overseerr"
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
              name = kubernetes_service_v1.overseerr.metadata[0].name
              port {
                number = 5055
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.overseerr,
    time_sleep.wait_for_overseerr
  ]
}

# HTTPS Ingress for Overseerr local domain (with self-signed TLS certificate)
# Uses the default TLS store in kube-system namespace
resource "kubernetes_ingress_v1" "overseerr_local" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "overseerr-local"
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
      hosts = ["overseerr.${var.local_domain}"]
      # No secret_name - uses default certificate from TLSStore
    }
    rule {
      host = "overseerr.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.overseerr.metadata[0].name
              port {
                number = 5055
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.overseerr,
    time_sleep.wait_for_overseerr
  ]
}

# HTTP Ingress for Overseerr local domain (redirects to HTTPS)
resource "kubernetes_ingress_v1" "overseerr_local_http" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "overseerr-local-http"
    namespace = var.namespace
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      "traefik.ingress.kubernetes.io/router.middlewares" = "default-https-redirect@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "overseerr.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.overseerr.metadata[0].name
              port {
                number = 5055
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.overseerr,
    time_sleep.wait_for_overseerr
  ]
}
