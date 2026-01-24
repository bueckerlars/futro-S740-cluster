output "tautulli_urls" {
  description = "URLs to access Tautulli (all domains)"
  value = {
    external = "https://${var.domain}"
    local    = var.local_domain != "" ? "https://tautulli.${var.local_domain}" : null
  }
}

output "namespace" {
  description = "Namespace where Tautulli resources are deployed"
  value       = var.namespace
}
