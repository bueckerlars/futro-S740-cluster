variable "network" {
  description = "Network configuration"
  type = object({
    subnet        = string
    gateway       = string
    dns_servers   = list(string)
    interface     = string
  })
  default = {
    subnet      = "192.168.178.0/24"
    gateway     = "192.168.178.1"
    dns_servers = ["192.168.178.11", "8.8.8.8"]
    interface   = "eth0"
  }
}

variable "master_node" {
  description = "Master node configuration"
  type = object({
    hostname = string
    ip       = string
  })
  default = {
    hostname = "k3s-master"
    ip       = "192.168.178.15"
  }
}

variable "worker_nodes" {
  description = "Worker nodes configuration"
  type = list(object({
    hostname = string
    ip       = string
  }))
  default = [
    {
      hostname = "k3s-worker-1"
      ip       = "192.168.178.16"
    },
    {
      hostname = "k3s-worker-2"
      ip       = "192.168.178.17"
    },
    {
      hostname = "k3s-worker-3"
      ip       = "192.168.178.18"
    }
  ]
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
  default = {
    name              = "kairos"
    password_hash     = "$6$y3/5WFtimmHRlw8M$AGYwQ7.6PMHEVJuXM0eMbUFxNbFNMGvOCXPCYh9YPxbhtKPZjsd93BLIzwO2P1GD7VCHw/fNJ9IcB3X/0Dn.r/"
    ssh_authorized_keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNhDoOFJmaqqQjL0/0mzaLb4eGqKVKcjkh4Sslltf0NcBNwWYiOyRzhbJbKEEjEug8+lSJkBqgIyZc9P0JJaaB6nZVV82+EBfPnumiVQD2hjMPN8Sfwqaqj6xZHbPNelHUdauE5uUOJByE1LkBAspaNYvieYelcdAiAGUtozqAzrU68kfAx8jYjUJVeLZCT51eFY6Ml3nBYO9qTymaFZlI/q9nZKbhNX1dPamq8Fg4UNgBmX7iql860BJu1Gpeas12kxJXR7CAmY0pGtp+Y33TsefqRZotlPcU2qDY70cBG6PcipGKR3pFCqA8kgtODGmVOZPN8KzwJGTYVgDMJfMipJO5D2jBqeE/PJ7rWBS0zrqOsYBtn6z+ZJaOZVykR8dONtoir5slSrXx3vLNdGWMZJYy1C2jP4XChwnl07Qs8CYTw3Cs+LOIqOD5AMiOvleQJWgR77S2fDW4Rg5BsX3Mzy3KsyCMO18fP3mO4IjJogBhPrtNOWJPAXN27HtN555y70DF8zpWfyIj1Uk0KxNbaLAbB70RAIcB0DHF0jelwKrlluhIzEOHjpqzcU/8PP1uF6G06WBzF5mWWwAwBQeGd/pKNBRcYmTJoJ7jAnQcOAHqliGWoiP9dXOdKg7WxqM6RmhEry1nebwwunt4w19VMDgPqp3hwr/H0UpDolwjxQ== lars.buecker1@gmail.com"
    ]
    groups            = ["admin", "sudo", "docker", "wheel"]
    shell             = "/bin/bash"
  }
}

variable "k3s" {
  description = "K3s configuration"
  type = object({
    token              = string
    flannel_backend    = string
    master_node_ip     = string
  })
  sensitive = true
  default = {
    token              = "K1091007c87f9b81a426633d1c04f792e3239f59d4c112c6ac8dd015b57b057419e::server:a606a869eca59305ac2a4f596fce0a2f"
    flannel_backend    = "host-gw"
    master_node_ip     = "192.168.178.15"
  }
}

variable "k3s_api_endpoint" {
  description = "K3s API endpoint"
  type        = string
  default     = "https://192.168.178.15:6443"
}

variable "k3s_token" {
  description = "K3s token for API access"
  type        = string
  sensitive   = true
  default     = "K1091007c87f9b81a426633d1c04f792e3239f59d4c112c6ac8dd015b57b057419e::server:a606a869eca59305ac2a4f596fce0a2f"
}

variable "install_device" {
  description = "Installation device for Kairos"
  type        = string
  default     = "/dev/sda"
}

variable "output_dir" {
  description = "Directory where cloud-init files will be written"
  type        = string
  default     = "../configs/cloud-init"
}

