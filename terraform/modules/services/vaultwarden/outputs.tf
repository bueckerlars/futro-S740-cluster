output "vaultwarden_url" {
  description = "URL to access Vaultwarden"
  value       = "https://${var.domain}"
}

output "namespace" {
  description = "Namespace where Vaultwarden resources are deployed"
  value       = var.namespace
}

