variable "hostname" {
  description = "Hostname for the master node"
  type        = string
}

variable "ip_address" {
  description = "IP address for the master node"
  type        = string
}

variable "network" {
  description = "Network configuration"
  type = object({
    subnet      = string
    gateway     = string
    dns_servers = list(string)
    interface   = string
  })
}

variable "user" {
  description = "User configuration"
  type = object({
    name              = string
    password_hash     = string
    ssh_authorized_keys = list(string)
    groups            = list(string)
    shell             = string
  })
}

variable "k3s" {
  description = "K3s configuration"
  type = object({
    token              = string
    flannel_backend    = string
    master_node_ip     = string
  })
  sensitive = true
}

variable "install_device" {
  description = "Installation device for Kairos"
  type        = string
}

variable "worker_nodes" {
  description = "Worker nodes configuration for hosts file"
  type = list(object({
    hostname = string
    ip       = string
  }))
}

variable "output_dir" {
  description = "Directory where cloud-init file will be written"
  type        = string
}

