output "namespace" {
  description = "Namespace where Paperless NGX is deployed"
  value       = kubernetes_namespace.paperless.metadata[0].name
}

output "domain" {
  description = "Domain name for Paperless NGX"
  value       = var.domain
}

