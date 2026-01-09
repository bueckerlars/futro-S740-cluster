output "master_ip" {
  description = "IP address of the K3S master node"
  value       = local.master_ip
}

output "node_hostnames" {
  description = "Map of node keys to their hostnames"
  value       = local.node_hostnames
}

output "nfs_storage_class" {
  description = "Name of the NFS StorageClass (default storage class)"
  value       = "nfs"
}

output "nfs_provisioner_status" {
  description = "Status of the NFS provisioner Helm release"
  value       = helm_release.nfs_provisioner.status
}

# Monitoring outputs
output "prometheus_urls" {
  description = "URLs to access Prometheus (all domains)"
  value       = module.monitoring.prometheus_urls
}

output "grafana_urls" {
  description = "URLs to access Grafana (all domains)"
  value       = module.monitoring.grafana_urls
}

output "grafana_admin_password" {
  description = "Admin password for Grafana"
  value       = module.monitoring.grafana_admin_password
  sensitive   = true
}

# External services outputs
output "external_service_urls" {
  description = "URLs to access external services (all domains)"
  value       = length(var.external_services) > 0 ? module.external_services[0].service_urls : {}
}

# Vaultwarden outputs
output "vaultwarden_urls" {
  description = "URLs to access Vaultwarden (all domains)"
  value       = module.vaultwarden.vaultwarden_urls
}

