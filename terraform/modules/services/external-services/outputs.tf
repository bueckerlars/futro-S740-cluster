output "service_urls" {
  description = "Map of service names to their HTTPS URLs (all domains)"
  value = {
    for k, v in var.services : k => {
      external = "https://${v.domain}"
      local    = var.local_domain != "" ? "https://${k}.${var.local_domain}" : null
    }
  }
}

output "service_names" {
  description = "List of created service names"
  value       = keys(var.services)
}

