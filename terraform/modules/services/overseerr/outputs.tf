output "overseerr_urls" {
  description = "URLs to access Overseerr (all domains)"
  value = {
    external = "https://${var.domain}"
    local    = var.local_domain != "" ? "https://overseerr.${var.local_domain}" : null
  }
}

output "namespace" {
  description = "Namespace where Overseerr resources are deployed"
  value       = var.namespace
}
