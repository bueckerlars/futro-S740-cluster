variable "master_ip" {
  type        = string
  description = "IP address of the K3S master node"
}

variable "nfs_server" {
  type        = string
  description = "NFS server IP address or hostname"
  default     = "192.168.178.10"
}

variable "nfs_export_path" {
  type        = string
  description = "NFS export path"
  default     = "/mnt/SSD-Pool/k3s-storage"
}

