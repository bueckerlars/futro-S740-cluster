output "couchdb_urls" {
  description = "URLs to access CouchDB (all domains)"
  value = {
    external = "https://${var.domain}"
    local    = var.local_domain != "" ? "https://couchdb.${var.local_domain}" : null
  }
}

output "namespace" {
  description = "Namespace where CouchDB resources are deployed"
  value       = var.namespace
}
