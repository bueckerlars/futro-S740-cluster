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

