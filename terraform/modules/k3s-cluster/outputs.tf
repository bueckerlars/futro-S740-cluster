output "master_ip" {
  description = "IP address of the K3S master node"
  value       = local.master_ip
}

output "node_hostnames" {
  description = "Map of node keys to their hostnames"
  value       = local.node_hostnames
}

output "nodes" {
  description = "Map of all nodes (for reference)"
  value       = local.nodes
}

