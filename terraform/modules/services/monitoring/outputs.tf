output "prometheus_urls" {
  description = "URLs to access Prometheus (all domains)"
  value = {
    local = var.local_domain != "" ? "https://prometheus.${var.local_domain}" : null
  }
}

output "grafana_urls" {
  description = "URLs to access Grafana (all domains)"
  value = {
    external = "https://grafana.${var.domain}"
    local    = var.local_domain != "" ? "https://grafana.${var.local_domain}" : null
  }
}

output "grafana_admin_password" {
  description = "Admin password for Grafana"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "namespace" {
  description = "Namespace where monitoring resources are deployed"
  value       = var.namespace
}

