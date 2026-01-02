variable "k3s_token" {
  type      = string
  sensitive = true
}

variable "dns_server" {
  type        = string
  description = "DNS server IP address"
  default     = "192.168.178.11"
}

variable "gateway" {
  type        = string
  description = "Gateway IP address"
  default     = "192.168.178.1"
}

variable "password_hash" {
  type        = string
  description = "Password hash for the kairos user"
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for the kairos user"
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

variable "nfs_mount_options" {
  type        = string
  description = "NFS mount options"
  default     = "rw,sync,hard,intr"
}

