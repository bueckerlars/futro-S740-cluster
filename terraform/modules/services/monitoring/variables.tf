variable "namespace" {
  type        = string
  description = "Namespace for monitoring resources"
  default     = "monitoring"
}

variable "grafana_admin_password" {
  type        = string
  description = "Admin password for Grafana"
  sensitive   = true
  default     = "admin"
}

variable "domain" {
  type        = string
  description = "Domain name for Ingress (e.g., example.com)"
}

variable "local_domain" {
  type        = string
  description = "Local domain name for Ingress (e.g., homelab.local). Used for local network access with self-signed certificates"
  default     = ""
}

