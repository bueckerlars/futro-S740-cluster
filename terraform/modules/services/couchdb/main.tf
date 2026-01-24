# CouchDB Service Module
# Deploys CouchDB using the official Helm chart with persistent storage

# Create couchdb namespace
resource "kubernetes_namespace" "couchdb" {
  metadata {
    name = var.namespace
  }
}

# CouchDB requires a stable node UUID
resource "random_uuid" "couchdb_uuid" {}

# Local values for Helm chart
locals {
  couchdb_values = yamlencode({
    fullnameOverride = "couchdb"
    clusterSize      = 1

    allowAdminParty   = false
    createAdminSecret = true
    adminUsername     = var.admin_user
    adminPassword     = var.admin_password

    couchdbConfig = {
      couchdb = {
        uuid              = random_uuid.couchdb_uuid.result
        max_document_size = 50000000
      }
      cluster = {
        n = 1
        q = 1
      }
      chttpd = {
        require_valid_user  = true
        enable_cors         = true
        max_http_request_size = 4294967296
      }
      chttpd_auth = {
        require_valid_user = true
      }
      httpd = {
        "WWW-Authenticate" = "Basic realm=\"couchdb\""
        enable_cors        = true
      }
      cors = {
        credentials = true
        origins     = "app://obsidian.md,capacitor://localhost,http://localhost"
      }
    }

    autoSetup = {
      enabled = true
      defaultDatabases = [
        "_users",
        "_replicator",
        "_global_changes"
      ]
    }

    networkPolicy = {
      enabled = false
    }

    persistentVolume = {
      enabled      = true
      size         = var.storage_size
      storageClass = "nfs"
    }

    podSecurityContext = {
      fsGroup = 5984
    }

    containerSecurityContext = {
      runAsUser    = 5984
      runAsGroup   = 5984
      runAsNonRoot = true
    }

    service = {
      type = "ClusterIP"
    }

    ingress = {
      enabled = false # We'll manage ingress separately via Terraform
    }
  })
}

# Helm Release for CouchDB
resource "helm_release" "couchdb" {
  name       = "couchdb"
  repository = "https://apache.github.io/couchdb-helm"
  chart      = "couchdb"
  namespace  = kubernetes_namespace.couchdb.metadata[0].name

  values = [
    local.couchdb_values
  ]

  # Wait for CouchDB to be ready
  wait    = true
  timeout = 600

  depends_on = [
    kubernetes_namespace.couchdb
  ]
}

# Wait for CouchDB service to be ready
resource "time_sleep" "wait_for_couchdb" {
  depends_on = [helm_release.couchdb]

  create_duration = "30s"
}

# Initialize CouchDB system databases when auto-setup hook is not available
resource "kubernetes_job_v1" "couchdb_init_dbs" {
  metadata {
    name      = "couchdb-init-dbs"
    namespace = kubernetes_namespace.couchdb.metadata[0].name
  }

  spec {
    backoff_limit = 2

    template {
      metadata {
        labels = {
          app = "couchdb-init-dbs"
        }
      }

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "init-dbs"
          image = "curlimages/curl:latest"

          command = [
            "sh",
            "-c",
            <<-EOT
              for i in $(seq 1 30); do
                if curl -sf -u "$COUCHDB_ADMIN:$COUCHDB_PASS" "http://$COUCHDB_ADDRESS/_up" > /dev/null; then
                  break
                fi
                sleep 2
              done

              curl -s -o /dev/null -u "$COUCHDB_ADMIN:$COUCHDB_PASS" \
                -X POST "http://$COUCHDB_ADDRESS/_cluster_setup" \
                -H "Content-Type: application/json" \
                -d "{\"action\":\"enable_single_node\",\"username\":\"$COUCHDB_ADMIN\",\"password\":\"$COUCHDB_PASS\",\"bind_address\":\"0.0.0.0\",\"port\":5984,\"singlenode\":true}" || true

              for db in _users _replicator _global_changes; do
                curl -s -o /dev/null -u "$COUCHDB_ADMIN:$COUCHDB_PASS" -X PUT "http://$COUCHDB_ADDRESS/$db" || true
              done
            EOT
          ]

          env {
            name  = "COUCHDB_ADDRESS"
            value = "couchdb-svc-couchdb.${kubernetes_namespace.couchdb.metadata[0].name}.svc.cluster.local:5984"
          }

          env {
            name = "COUCHDB_ADMIN"
            value_from {
              secret_key_ref {
                name = "couchdb-couchdb"
                key  = "adminUsername"
              }
            }
          }

          env {
            name = "COUCHDB_PASS"
            value_from {
              secret_key_ref {
                name = "couchdb-couchdb"
                key  = "adminPassword"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.couchdb,
    time_sleep.wait_for_couchdb
  ]
}

# HTTP Ingress for CouchDB (no TLS, works without certificates)
resource "kubernetes_ingress_v1" "couchdb_http" {
  metadata {
    name      = "couchdb-http"
    namespace = kubernetes_namespace.couchdb.metadata[0].name
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
              name = "couchdb-svc-couchdb"
              port {
                number = 5984
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.couchdb,
    time_sleep.wait_for_couchdb
  ]
}

# HTTPS Ingress for CouchDB (with TLS, requires certificates)
# Note: Must include 'web' entrypoint for ACME HTTP challenge to work
resource "kubernetes_ingress_v1" "couchdb" {
  metadata {
    name      = "couchdb"
    namespace = kubernetes_namespace.couchdb.metadata[0].name
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
              name = "couchdb-svc-couchdb"
              port {
                number = 5984
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.couchdb,
    time_sleep.wait_for_couchdb
  ]
}

# HTTPS Ingress for CouchDB local domain (with self-signed TLS certificate)
# Uses the default TLS store in kube-system namespace
resource "kubernetes_ingress_v1" "couchdb_local" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "couchdb-local"
    namespace = kubernetes_namespace.couchdb.metadata[0].name
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
      hosts = ["couchdb.${var.local_domain}"]
      # No secret_name - uses default certificate from TLSStore
    }
    rule {
      host = "couchdb.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "couchdb-svc-couchdb"
              port {
                number = 5984
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.couchdb,
    time_sleep.wait_for_couchdb
  ]
}

# HTTP Ingress for CouchDB local domain (redirects to HTTPS)
resource "kubernetes_ingress_v1" "couchdb_local_http" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "couchdb-local-http"
    namespace = kubernetes_namespace.couchdb.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      "traefik.ingress.kubernetes.io/router.middlewares" = "default-https-redirect@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "couchdb.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "couchdb-svc-couchdb"
              port {
                number = 5984
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.couchdb,
    time_sleep.wait_for_couchdb
  ]
}
