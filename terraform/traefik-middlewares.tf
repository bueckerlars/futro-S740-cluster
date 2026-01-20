# Traefik Middlewares
# Reusable middleware definitions for custom headers

resource "kubernetes_manifest" "traefik_middleware" {
  for_each = var.traefik_middlewares

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.key
      namespace = "default"
    }
    spec = {
      headers = {
        for k, v in each.value.headers : k => v
        if v != null && !(k == "customRequestHeaders" && try(length(v), 0) == 0) && !(k == "customResponseHeaders" && try(length(v), 0) == 0)
      }
    }
  }

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster
  ]
}

# Global HTTP to HTTPS redirect middleware
# This middleware automatically redirects all HTTP requests to HTTPS
resource "kubernetes_manifest" "https_redirect" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "https-redirect"
      namespace = "default"
    }
    spec = {
      redirectScheme = {
        scheme    = "https"
        permanent = true
      }
    }
  }

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster
  ]
}

