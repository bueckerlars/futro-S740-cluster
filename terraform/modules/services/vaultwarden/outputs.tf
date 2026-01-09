output "vaultwarden_urls" {
  description = "URLs to access Vaultwarden (all domains)"
  value = {
    external = "https://${var.domain}"
    local    = var.local_domain != "" ? "https://bitwarden.${var.local_domain}" : null
  }
}

output "namespace" {
  description = "Namespace where Vaultwarden resources are deployed"
  value       = var.namespace
}

