output "storage_class" {
  description = "Name of the NFS StorageClass (default storage class)"
  value       = "nfs"
}

output "provisioner_status" {
  description = "Status of the NFS provisioner Helm release"
  value       = helm_release.nfs_provisioner.status
}

