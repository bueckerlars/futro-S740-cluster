output "master_ip" {
  description = "IP address of the K3S master node"
  value       = local.master_ip
}

output "node_hostnames" {
  description = "Map of node keys to their hostnames"
  value       = local.node_hostnames
}

