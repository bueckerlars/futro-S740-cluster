output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = "http://${var.master_ip}:${var.prometheus_nodeport}"
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "http://${var.master_ip}:${var.grafana_nodeport}"
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

