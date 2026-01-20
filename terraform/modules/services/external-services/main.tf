# External Services Module
# Creates Kubernetes Services and Ingress resources for services running on external servers

# Local values for middleware annotations
locals {
  # Build middleware list for each service
  middleware_list = {
    for k, v in var.services : k => concat(
      # Reusable middlewares (from traefik_middlewares variable)
      [for m in v.middlewares : "${var.namespace}-${m}@kubernetescrd"],
      # Service-specific headers middleware (if headers are defined)
      length(v.headers) > 0 ? ["${var.namespace}-${k}-headers@kubernetescrd"] : []
    )
  }
  
  # Build annotations only if middlewares exist
  middleware_annotations = {
    for k, v in local.middleware_list : k => {
      "traefik.ingress.kubernetes.io/router.middlewares" = join(",", v)
    } if length(v) > 0
  }
}

# Create namespace if it doesn't exist
resource "kubernetes_namespace" "external_services" {
  count = var.namespace != "default" ? 1 : 0
  metadata {
    name = var.namespace
  }
}

# Create Endpoints for each external service
resource "kubernetes_endpoints_v1" "external_service" {
  for_each = var.services

  metadata {
    name      = each.key
    namespace = var.namespace
  }

  subset {
    address {
      ip = each.value.ip
    }
    port {
      port     = each.value.port
      protocol = "TCP"
    }
  }
}

# Create Service for each external service
resource "kubernetes_service_v1" "external_service" {
  for_each = var.services

  metadata {
    name      = each.key
    namespace = var.namespace
  }

  spec {
    type = "ClusterIP"
    port {
      port        = each.value.port
      target_port = each.value.port
      protocol    = "TCP"
    }
  }

  depends_on = [
    kubernetes_endpoints_v1.external_service
  ]
}

# Create ServersTransport for services that need to skip TLS verification
resource "kubernetes_manifest" "servers_transport" {
  for_each = {
    for k, v in var.services : k => v
    if v.insecure_skip_verify == true
  }

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "ServersTransport"
    metadata = {
      name      = "${each.key}-transport"
      namespace = var.namespace
    }
    spec = {
      insecureSkipVerify = true
    }
  }
}

# HTTP Ingress for each external service (redirects to HTTPS)
resource "kubernetes_ingress_v1" "external_service_http" {
  for_each = var.services

  metadata {
    name      = "${each.key}-http"
    namespace = var.namespace
    annotations = merge(
      {
        "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
        "traefik.ingress.kubernetes.io/router.middlewares" = "default-https-redirect@kubernetescrd"
      }
    )
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = each.value.domain
      http {
        path {
          path      = each.value.path
          path_type = "Prefix"
          backend {
            service {
              name = each.key
              port {
                number = each.value.port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.external_service
  ]
}

# HTTPS Ingress for each external service (with TLS, requires certificates)
# Note: Must include 'web' entrypoint for ACME HTTP challenge to work
resource "kubernetes_ingress_v1" "external_service" {
  for_each = var.services

  metadata {
    name      = each.key
    namespace = var.namespace
    annotations = merge(
      {
        "traefik.ingress.kubernetes.io/router.entrypoints"      = "web,websecure"
        "traefik.ingress.kubernetes.io/router.tls.certresolver" = var.letsencrypt_certresolver
      },
      # Set service scheme (http/https)
      each.value.scheme == "https" ? {
        "traefik.ingress.kubernetes.io/service.scheme" = "https"
      } : {},
      # Use ServersTransport if insecure_skip_verify is enabled
      each.value.insecure_skip_verify ? {
        "traefik.ingress.kubernetes.io/service.serversstransport" = "${var.namespace}-${each.key}-transport@kubernetescrd"
      } : {},
      # Build middleware list: reusable middlewares + service-specific headers middleware (if any)
      lookup(local.middleware_annotations, each.key, {})
    )
  }

  spec {
    ingress_class_name = "traefik"
    tls {
      hosts = [each.value.domain]
      # secret_name entfernt - Traefik erstellt das Secret automatisch
    }
    rule {
      host = each.value.domain
      http {
        path {
          path      = each.value.path
          path_type = "Prefix"
          backend {
            service {
              name = each.key
              port {
                number = each.value.port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.external_service
  ]
}

# Create Middleware for custom headers if headers are specified
resource "kubernetes_manifest" "headers_middleware" {
  for_each = {
    for k, v in var.services : k => v
    if length(v.headers) > 0
  }

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${each.key}-headers"
      namespace = var.namespace
    }
    spec = {
      headers = {
        customRequestHeaders = each.value.headers
      }
    }
  }
}

# HTTPS Ingress for local domain (with self-signed TLS certificate)
# Uses the default TLS store in kube-system namespace
resource "kubernetes_ingress_v1" "external_service_local" {
  for_each = var.local_domain != "" ? var.services : {}

  metadata {
    name      = "${each.key}-local"
    namespace = var.namespace
    annotations = merge(
      {
        "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
        # Use default TLS store (no certresolver, uses default certificate from TLSStore)
      },
      # Set service scheme (http/https)
      each.value.scheme == "https" ? {
        "traefik.ingress.kubernetes.io/service.scheme" = "https"
      } : {},
      # Use ServersTransport if insecure_skip_verify is enabled
      each.value.insecure_skip_verify ? {
        "traefik.ingress.kubernetes.io/service.serversstransport" = "${var.namespace}-${each.key}-transport@kubernetescrd"
      } : {},
      # Build middleware list: reusable middlewares + service-specific headers middleware (if any)
      lookup(local.middleware_annotations, each.key, {})
    )
  }

  spec {
    ingress_class_name = "traefik"
    tls {
      hosts = ["${each.key}.${var.local_domain}"]
      # No secret_name - uses default certificate from TLSStore
    }
    rule {
      host = "${each.key}.${var.local_domain}"
      http {
        path {
          path      = each.value.path
          path_type = "Prefix"
          backend {
            service {
              name = each.key
              port {
                number = each.value.port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.external_service
  ]
}

# HTTP Ingress for local domain (redirects to HTTPS)
resource "kubernetes_ingress_v1" "external_service_local_http" {
  for_each = var.local_domain != "" ? var.services : {}

  metadata {
    name      = "${each.key}-local-http"
    namespace = var.namespace
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      "traefik.ingress.kubernetes.io/router.middlewares"  = "default-https-redirect@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "${each.key}.${var.local_domain}"
      http {
        path {
          path      = each.value.path
          path_type = "Prefix"
          backend {
            service {
              name = each.key
              port {
                number = each.value.port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.external_service
  ]
}
