output "collabora_urls" {
  description = "URLs to access Collabora Online (all domains)"
  value = {
    external = "https://${var.domain}"
    local    = var.local_domain != "" ? "https://office.${var.local_domain}" : null
  }
}

output "namespace" {
  description = "Namespace where Collabora Online resources are deployed"
  value       = var.namespace
}
