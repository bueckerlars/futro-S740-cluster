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

