variable "namespace" {
  type        = string
  description = "Namespace for Vaultwarden resources"
  default     = "vaultwarden"
}

variable "domain" {
  type        = string
  description = "Domain name for Vaultwarden Ingress (e.g., bitwarden.carvin.cloud)"
}

variable "admin_token" {
  type        = string
  description = "Admin token for Vaultwarden admin panel"
  sensitive   = true
}

variable "storage_size" {
  type        = string
  description = "Size of persistent storage for Vaultwarden data"
  default     = "10Gi"
}

variable "letsencrypt_certresolver" {
  type        = string
  description = "Name of the Let's Encrypt cert resolver"
  default     = "letsencrypt"
}

variable "middlewares" {
  type        = list(string)
  description = "List of Traefik middleware names to apply to the Ingress"
  default     = ["standard-headers"]
}

variable "middleware_namespace" {
  type        = string
  description = "Namespace where the middlewares are defined"
  default     = "default"
}

variable "local_domain" {
  type        = string
  description = "Local domain name for Ingress (e.g., homelab.local). Used for local network access with self-signed certificates"
  default     = ""
}

