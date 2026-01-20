# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
  }
}

# Local values for Helm chart
locals {
  prometheus_values = yamlencode({
    prometheus = {
      prometheusSpec = {
        retention                               = "15d"
        serviceMonitorSelectorNilUsesHelmValues = false
        additionalScrapeConfigs = [
          {
            job_name        = "kubernetes-nodes-cadvisor"
            scrape_interval = "10s"
            scrape_timeout  = "10s"
            scheme          = "https"
            tls_config = {
              ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
            }
            bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
            kubernetes_sd_configs = [
              {
                role = "node"
              }
            ]
            relabel_configs = [
              {
                action = "labelmap"
                regex  = "__meta_kubernetes_node_label_(.+)"
              },
              {
                target_label = "__address__"
                replacement  = "kubernetes.default.svc:443"
              },
              {
                source_labels = ["__meta_kubernetes_node_name"]
                regex         = "(.+)"
                target_label  = "__metrics_path__"
                replacement   = "/api/v1/nodes/${1}/proxy/metrics/cadvisor"
              }
            ]
            metric_relabel_configs = [
              {
                action        = "replace"
                source_labels = ["id"]
                regex         = "^/machine\\.slice/machine-rkt\\\\x2d([^\\\\]+)\\.+/([^/]+)\\.service$"
                target_label  = "rkt_container_name"
                replacement   = "${2}-${1}"
              },
              {
                action        = "replace"
                source_labels = ["id"]
                regex         = "^/system\\.slice/(.+)\\.service$"
                target_label  = "systemd_service_name"
                replacement   = "${1}"
              }
            ]
          }
        ]
      }
      service = {
        type = "ClusterIP"
      }
    }
    grafana = {
      adminPassword = var.grafana_admin_password
      service = {
        type = "ClusterIP"
      }
      sidecar = {
        dashboards = {
          enabled = true
          label   = "grafana_dashboard"
        }
      }
    }
    prometheusOperator = {
      enabled = true
    }
  })
}

# Helm Release for kube-prometheus-stack
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "58.0.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    local.prometheus_values
  ]

  # Wait for Grafana to be ready
  wait    = true
  timeout = 600
}

# Wait for Grafana service to be ready
resource "time_sleep" "wait_for_grafana" {
  depends_on = [helm_release.kube_prometheus_stack]

  create_duration = "30s"
}

# HTTP Ingress for Grafana (redirects to HTTPS)
resource "kubernetes_ingress_v1" "grafana_http" {
  metadata {
    name      = "grafana-http"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      "traefik.ingress.kubernetes.io/router.middlewares" = "default-https-redirect@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "grafana.${var.domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
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
    helm_release.kube_prometheus_stack,
    time_sleep.wait_for_grafana
  ]
}

# HTTPS Ingress for Grafana (with TLS, requires certificates)
# Note: Must include 'web' entrypoint for ACME HTTP challenge to work
resource "kubernetes_ingress_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints"      = "web,websecure"
      "traefik.ingress.kubernetes.io/router.tls.certresolver" = "letsencrypt"
      "traefik.ingress.kubernetes.io/router.middlewares"      = "default-standard-headers@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    tls {
      hosts = ["grafana.${var.domain}"]
      # secret_name entfernt - Traefik erstellt das Secret automatisch mit dem CertResolver
    }
    rule {
      host = "grafana.${var.domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
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
    helm_release.kube_prometheus_stack,
    time_sleep.wait_for_grafana
  ]
}

# HTTPS Ingress for Grafana local domain (with self-signed TLS certificate)
# Uses the default TLS store in kube-system namespace
resource "kubernetes_ingress_v1" "grafana_local" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "grafana-local"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.middlewares" = "default-standard-headers@kubernetescrd"
      # Use default TLS store (no certresolver, uses default certificate from TLSStore)
    }
  }

  spec {
    ingress_class_name = "traefik"
    tls {
      hosts = ["grafana.${var.local_domain}"]
      # No secret_name - uses default certificate from TLSStore
    }
    rule {
      host = "grafana.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
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
    helm_release.kube_prometheus_stack,
    time_sleep.wait_for_grafana
  ]
}

# HTTP Ingress for Grafana local domain (redirects to HTTPS)
resource "kubernetes_ingress_v1" "grafana_local_http" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "grafana-local-http"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      "traefik.ingress.kubernetes.io/router.middlewares" = "default-https-redirect@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "grafana.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
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
    helm_release.kube_prometheus_stack,
    time_sleep.wait_for_grafana
  ]
}

# HTTPS Ingress for Prometheus local domain (with self-signed TLS certificate)
resource "kubernetes_ingress_v1" "prometheus_local" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "prometheus-local"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.middlewares" = "default-standard-headers@kubernetescrd"
      # Use default TLS store (no certresolver, uses default certificate from TLSStore)
    }
  }

  spec {
    ingress_class_name = "traefik"
    tls {
      hosts = ["prometheus.${var.local_domain}"]
      # No secret_name - uses default certificate from TLSStore
    }
    rule {
      host = "prometheus.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-prometheus"
              port {
                number = 9090
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack,
    time_sleep.wait_for_grafana
  ]
}

# HTTP Ingress for Prometheus local domain (redirects to HTTPS)
resource "kubernetes_ingress_v1" "prometheus_local_http" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "prometheus-local-http"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
      "traefik.ingress.kubernetes.io/router.middlewares" = "default-https-redirect@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"
    rule {
      host = "prometheus.${var.local_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-prometheus"
              port {
                number = 9090
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack,
    time_sleep.wait_for_grafana
  ]
}

# Import Grafana Dashboard 315 via API
resource "null_resource" "import_grafana_dashboard" {
  depends_on = [
    helm_release.kube_prometheus_stack,
    time_sleep.wait_for_grafana,
    kubernetes_ingress_v1.grafana
  ]

  triggers = {
    grafana_url  = "https://grafana.${var.domain}"
    dashboard_id = "315"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for Grafana to be accessible via Ingress
      max_attempts=30
      attempt=0
      while [ $attempt -lt $max_attempts ]; do
        if curl -s -f -k -u admin:${var.grafana_admin_password} "https://grafana.${var.domain}/api/health" > /dev/null 2>&1; then
          echo "Grafana is ready"
          break
        fi
        attempt=$((attempt + 1))
        echo "Waiting for Grafana... attempt $attempt/$max_attempts"
        sleep 5
      done

      # Import dashboard 315
      curl -s -X POST \
        -k \
        -u admin:${var.grafana_admin_password} \
        -H "Content-Type: application/json" \
        -d '{"dashboardId": 315, "overwrite": true}' \
        "https://grafana.${var.domain}/api/dashboards/import" || \
      curl -s -X POST \
        -k \
        -u admin:${var.grafana_admin_password} \
        -H "Content-Type: application/json" \
        -d '{"uid": "315", "overwrite": true}' \
        "https://grafana.${var.domain}/api/dashboards/db" || \
      echo "Dashboard import attempted. You may need to import manually via Grafana UI: https://grafana.${var.domain}/d/315"
    EOT
  }
}

