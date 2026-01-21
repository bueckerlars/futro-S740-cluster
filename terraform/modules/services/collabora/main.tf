# Collabora Online Service Module
# Deploys Collabora Online as a Kubernetes Deployment with WebSocket support

# Create collabora namespace
resource "kubernetes_namespace" "collabora" {
  metadata {
    name = var.namespace
  }
}

# Format WOPI domains as regex (escape dots)
# Remove https:// or http:// prefix if present, then escape dots for regex
locals {
  wopi_domain_regex = join("|", [
    for d in var.wopi_domains : replace(
      replace(replace(d, "https://", ""), "http://", ""),
      ".",
      "\\."
    )
  ])
}

# Collabora Online Deployment
resource "kubernetes_deployment_v1" "collabora" {
  metadata {
    name      = "collabora"
    namespace = kubernetes_namespace.collabora.metadata[0].name
    labels = {
      app = "collabora"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "collabora"
      }
    }

    template {
      metadata {
        labels = {
          app = "collabora"
        }
      }

      spec {
        container {
          name  = "collabora"
          image = "collabora/code:latest"

          port {
            container_port = 9980
            name           = "http"
          }

          env {
            name  = "username"
            value = var.admin_user
          }

          env {
            name  = "password"
            value = var.admin_password
          }

          env {
            name  = "domain"
            value = local.wopi_domain_regex
          }

          env {
            name  = "server_name"
            value = "${var.domain}:443"
          }

          env {
            name  = "extra_params"
            value = "--o:ssl.termination=true --o:ssl.enable=false"
          }

          env {
            name  = "DONT_GEN_SSL_CERT"
            value = "true"
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "2000m"
              memory = "2Gi"
            }
          }
        }
      }
    }
  }
}

# Collabora Service
resource "kubernetes_service_v1" "collabora" {
  metadata {
    name      = "collabora"
    namespace = kubernetes_namespace.collabora.metadata[0].name
    labels = {
      app = "collabora"
    }
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = "collabora"
    }
    port {
      port        = 9980
      target_port = 9980
      protocol    = "TCP"
    }
  }

  depends_on = [
    kubernetes_deployment_v1.collabora
  ]
}

# Wait for Collabora service to be ready
resource "time_sleep" "wait_for_collabora" {
  depends_on = [kubernetes_service_v1.collabora]

  create_duration = "30s"
}

# HTTP Ingress for Collabora (no TLS, works without certificates)
resource "kubernetes_ingress_v1" "collabora_http" {
  metadata {
    name      = "collabora-http"
    namespace = kubernetes_namespace.collabora.metadata[0].name
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
              name = kubernetes_service_v1.collabora.metadata[0].name
              port {
                number = 9980
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.collabora,
    time_sleep.wait_for_collabora
  ]
}

# HTTPS Ingress for Collabora (with TLS, requires certificates)
# Note: Must include 'web' entrypoint for ACME HTTP challenge to work
# Traefik supports WebSockets automatically, no special annotations needed
resource "kubernetes_ingress_v1" "collabora" {
  metadata {
    name      = "collabora"
    namespace = kubernetes_namespace.collabora.metadata[0].name
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
              name = kubernetes_service_v1.collabora.metadata[0].name
              port {
                number = 9980
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.collabora,
    time_sleep.wait_for_collabora
  ]
}

# HTTPS Ingress for Collabora local domain (with self-signed TLS certificate)
# Uses the default TLS store in kube-system namespace
resource "kubernetes_ingress_v1" "collabora_local" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "collabora-local"
    namespace = kubernetes_namespace.collabora.metadata[0].name
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
      hosts = ["office.${var.local_domain}"]
      # No secret_name - uses default certificate from TLSStore
    }
    rule {
      host = "office.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.collabora.metadata[0].name
              port {
                number = 9980
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.collabora,
    time_sleep.wait_for_collabora
  ]
}

# HTTP Ingress for Collabora local domain (redirects to HTTPS)
resource "kubernetes_ingress_v1" "collabora_local_http" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "collabora-local-http"
    namespace = kubernetes_namespace.collabora.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      "traefik.ingress.kubernetes.io/router.middlewares" = "default-https-redirect@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "office.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.collabora.metadata[0].name
              port {
                number = 9980
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.collabora,
    time_sleep.wait_for_collabora
  ]
}
