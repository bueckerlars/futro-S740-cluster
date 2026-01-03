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
output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = module.monitoring.prometheus_url
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = module.monitoring.grafana_url
}

output "grafana_admin_password" {
  description = "Admin password for Grafana"
  value       = module.monitoring.grafana_admin_password
  sensitive   = true
}

