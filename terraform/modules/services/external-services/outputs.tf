output "service_urls" {
  description = "Map of service names to their HTTPS URLs"
  value = {
    for k, v in var.services : k => "https://${v.domain}"
  }
}

output "service_names" {
  description = "List of created service names"
  value       = keys(var.services)
}

