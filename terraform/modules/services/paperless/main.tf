# Paperless NGX Service Module
# Deploys Paperless NGX using the official Helm chart with persistent storage

# Create paperless namespace
resource "kubernetes_namespace" "paperless" {
  metadata {
    name = var.namespace
  }
}

# Generate secret key if not provided
resource "random_string" "secret_key" {
  count   = var.secret_key == "" ? 1 : 0
  length  = 64
  special = true
  upper   = true
  lower   = true
  numeric = true
}

locals {
  paperless_secret_key = var.secret_key != "" ? var.secret_key : random_string.secret_key[0].result
}

# PersistentVolumeClaim for media (uses nfs-storage storage class for /mnt/Storage/paperless)
resource "kubernetes_persistent_volume_claim_v1" "paperless_media" {
  metadata {
    name      = "paperless-media"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.storage_media_size
      }
    }
    storage_class_name = "nfs-storage" # Uses second NFS provisioner for /mnt/Storage
  }
}

# PersistentVolumeClaim for data (uses nfs-storage storage class for /mnt/Storage/paperless)
resource "kubernetes_persistent_volume_claim_v1" "paperless_data" {
  metadata {
    name      = "paperless-data"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.storage_data_size
      }
    }
    storage_class_name = "nfs-storage" # Uses second NFS provisioner for /mnt/Storage
  }
}

# PersistentVolumeClaim for consume (uses nfs-storage storage class for /mnt/Storage/paperless)
resource "kubernetes_persistent_volume_claim_v1" "paperless_consume" {
  metadata {
    name      = "paperless-consume"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.storage_consume_size
      }
    }
    storage_class_name = "nfs-storage" # Uses second NFS provisioner for /mnt/Storage
  }
}

# PersistentVolumeClaim for export (uses nfs-storage storage class for /mnt/Storage/paperless)
resource "kubernetes_persistent_volume_claim_v1" "paperless_export" {
  metadata {
    name      = "paperless-export"
    namespace = kubernetes_namespace.paperless.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.storage_export_size
      }
    }
    storage_class_name = "nfs-storage" # Uses second NFS provisioner for /mnt/Storage
  }
}

# Local values for Helm chart
locals {
  paperless_values = yamlencode({
    ingress = {
      main = {
        enabled = false # We'll manage ingress separately via Terraform
      }
    }
    service = {
      main = {
        ports = {
          http = {
            port = 8000
          }
        }
      }
    }
    persistence = {
      media = {
        enabled       = true
        existingClaim = kubernetes_persistent_volume_claim_v1.paperless_media.metadata[0].name
      }
      data = {
        enabled       = true
        existingClaim = kubernetes_persistent_volume_claim_v1.paperless_data.metadata[0].name
      }
      consume = {
        enabled       = true
        existingClaim = kubernetes_persistent_volume_claim_v1.paperless_consume.metadata[0].name
      }
      export = {
        enabled       = true
        existingClaim = kubernetes_persistent_volume_claim_v1.paperless_export.metadata[0].name
      }
    }
    deployment = {
      strategy = {
        type = "Recreate" # Required for ReadWriteOnce volumes to avoid lock conflicts
      }
    }
    env = {
      TZ                    = var.time_zone # Container timezone
      PAPERLESS_URL         = "https://${var.domain}"
      PAPERLESS_TIME_ZONE   = var.time_zone
      PAPERLESS_OCR_LANGUAGE = var.ocr_language
      PAPERLESS_OCR_LANGUAGES = var.ocr_languages
      PAPERLESS_SECRET_KEY  = local.paperless_secret_key
      PAPERLESS_CONSUMPTION_DIR = "/usr/src/paperless/consume"
      PAPERLESS_EXPORT_DIR  = "/usr/src/paperless/export"
      PAPERLESS_DATA_DIR    = "/usr/src/paperless/data"
      # CSRF and security settings for reverse proxy
      # ALLOWED_HOSTS: Comma-separated list of allowed hostnames
      PAPERLESS_ALLOWED_HOSTS = var.local_domain != "" ? "${var.domain},paperless.${var.local_domain}" : var.domain
      # CSRF_TRUSTED_ORIGINS: Comma-separated list of trusted origins (must include protocol)
      PAPERLESS_CSRF_TRUSTED_ORIGINS = var.local_domain != "" ? "https://${var.domain},https://paperless.${var.local_domain}" : "https://${var.domain}"
      # Admin user configuration
      PAPERLESS_ADMIN_USER     = var.admin_user
      PAPERLESS_ADMIN_PASSWORD = var.admin_password
    }
    # Redis and PostgreSQL are managed by the Helm chart
    # Using Bitnami Legacy repository due to Bitnami moving images behind paywall
    redis = {
      enabled = true
      image = {
        repository = "bitnami/redis"
        tag        = "latest"
      }
    }
    postgresql = {
      enabled = true
      image = {
        repository = "bitnami/postgresql"
        tag        = "latest"
      }
      auth = {
        database = "paperless"
        username = "paperless"
        password = "paperless" # Default password, should be changed in production
      }
    }
  })
}

# Helm Release for Paperless NGX
resource "helm_release" "paperless" {
  name       = "paperless-ngx"
  repository = "oci://ghcr.io/gabe565/charts"
  chart      = "paperless-ngx"
  namespace  = kubernetes_namespace.paperless.metadata[0].name

  values = [
    local.paperless_values
  ]

  # Wait for Paperless to be ready
  wait    = true
  timeout = 600

  depends_on = [
    kubernetes_persistent_volume_claim_v1.paperless_media,
    kubernetes_persistent_volume_claim_v1.paperless_data,
    kubernetes_persistent_volume_claim_v1.paperless_consume,
    kubernetes_persistent_volume_claim_v1.paperless_export
  ]
}

# Wait for Paperless service to be ready
resource "time_sleep" "wait_for_paperless" {
  depends_on = [helm_release.paperless]

  create_duration = "30s"
}

# HTTP Ingress for Paperless (no TLS, works without certificates)
resource "kubernetes_ingress_v1" "paperless_http" {
  metadata {
    name      = "paperless-http"
    namespace = kubernetes_namespace.paperless.metadata[0].name
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
              name = "paperless-ngx"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.paperless,
    time_sleep.wait_for_paperless
  ]
}

# HTTPS Ingress for Paperless (with TLS, requires certificates)
# Note: Must include 'web' entrypoint for ACME HTTP challenge to work
resource "kubernetes_ingress_v1" "paperless" {
  metadata {
    name      = "paperless"
    namespace = kubernetes_namespace.paperless.metadata[0].name
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
              name = "paperless-ngx"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.paperless,
    time_sleep.wait_for_paperless
  ]
}

# HTTPS Ingress for Paperless local domain (with self-signed TLS certificate)
# Uses the default TLS store in kube-system namespace
resource "kubernetes_ingress_v1" "paperless_local" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "paperless-local"
    namespace = kubernetes_namespace.paperless.metadata[0].name
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
      hosts = ["paperless.${var.local_domain}"]
      # No secret_name - uses default certificate from TLSStore
    }
    rule {
      host = "paperless.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "paperless-ngx"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.paperless,
    time_sleep.wait_for_paperless
  ]
}

# HTTP Ingress for Paperless local domain (redirects to HTTPS)
resource "kubernetes_ingress_v1" "paperless_local_http" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "paperless-local-http"
    namespace = kubernetes_namespace.paperless.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      "traefik.ingress.kubernetes.io/router.middlewares"  = "default-https-redirect@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "paperless.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "paperless-ngx"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.paperless,
    time_sleep.wait_for_paperless
  ]
}

