# Forgejo Service Module
# Deploys Forgejo using the official Helm chart with persistent storage

# Create forgejo namespace
resource "kubernetes_namespace" "forgejo" {
  metadata {
    name = var.namespace
  }
}

# PersistentVolumeClaim for Forgejo data and repositories
resource "kubernetes_persistent_volume_claim_v1" "forgejo_data" {
  metadata {
    name      = "forgejo-data"
    namespace = kubernetes_namespace.forgejo.metadata[0].name
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

# Local values for Helm chart
locals {
  forgejo_values = yamlencode({
    persistence = {
      enabled       = true
      existingClaim = kubernetes_persistent_volume_claim_v1.forgejo_data.metadata[0].name
    }
    service = {
      type     = "ClusterIP"
      httpPort = 3000
    }
    ingress = {
      enabled = false  # We'll manage ingress separately via Terraform
    }
    gitea = {
      admin = {
        username = "gitea_admin"
        password = var.admin_password
        email    = var.admin_email != "" ? var.admin_email : "admin@${var.domain}"
      }
      config = {
        server = {
          DOMAIN           = var.domain
          ROOT_URL         = "https://${var.domain}/"
          HTTP_PORT        = 3000
          DISABLE_SSH      = false
          START_SSH_SERVER = false
        }
        service = {
          DISABLE_REGISTRATION = false
        }
      }
    }
  })
}

# Helm Release for Forgejo
resource "helm_release" "forgejo" {
  name       = "forgejo"
  repository = "oci://code.forgejo.org/forgejo-helm"
  chart      = "forgejo"
  namespace  = kubernetes_namespace.forgejo.metadata[0].name

  values = [
    local.forgejo_values
  ]

  # Wait for Forgejo to be ready
  wait = true
  timeout = 600

  depends_on = [
    kubernetes_persistent_volume_claim_v1.forgejo_data
  ]
}

# Wait for Forgejo service to be ready
resource "time_sleep" "wait_for_forgejo" {
  depends_on = [helm_release.forgejo]

  create_duration = "30s"
}

# HTTPS Ingress for Forgejo (with TLS, requires certificates)
# Note: Must include 'web' entrypoint for ACME HTTP challenge to work
resource "kubernetes_ingress_v1" "forgejo" {
  metadata {
    name      = "forgejo"
    namespace = kubernetes_namespace.forgejo.metadata[0].name
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
              name = "forgejo-http"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.forgejo,
    time_sleep.wait_for_forgejo
  ]
}

# HTTPS Ingress for Forgejo local domain (with self-signed TLS certificate)
# Uses the default TLS store in kube-system namespace
resource "kubernetes_ingress_v1" "forgejo_local" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "forgejo-local"
    namespace = kubernetes_namespace.forgejo.metadata[0].name
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
      hosts = ["git.${var.local_domain}"]
      # No secret_name - uses default certificate from TLSStore
    }
    rule {
      host = "git.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "forgejo-http"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.forgejo,
    time_sleep.wait_for_forgejo
  ]
}

# HTTP Ingress for Forgejo local domain (redirects to HTTPS)
resource "kubernetes_ingress_v1" "forgejo_local_http" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "forgejo-local-http"
    namespace = kubernetes_namespace.forgejo.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      "traefik.ingress.kubernetes.io/router.middlewares"  = "default-https-redirect@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "git.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "forgejo-http"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.forgejo,
    time_sleep.wait_for_forgejo
  ]
}
