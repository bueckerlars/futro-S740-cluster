output "cloud_init_files" {
  description = "Paths to generated cloud-init files"
  value = {
    master = module.cloud_init_master.output_file
    workers = {
      for k, v in module.cloud_init_workers : k => v.output_file
    }
  }
}

output "master_node" {
  description = "Master node information"
  value = {
    hostname = var.master_node.hostname
    ip       = var.master_node.ip
  }
}

output "worker_nodes" {
  description = "Worker nodes information"
  value = {
    for node in var.worker_nodes : node.hostname => {
      hostname = node.hostname
      ip       = node.ip
    }
  }
}

output "k3s_api_endpoint" {
  description = "K3s API endpoint"
  value       = var.k3s_api_endpoint
}

output "cluster_nodes" {
  description = "All cluster nodes with their IPs"
  value = merge(
    {
      (var.master_node.hostname) = var.master_node.ip
    },
    {
      for node in var.worker_nodes : node.hostname => node.ip
    }
  )
}

