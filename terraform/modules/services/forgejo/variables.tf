variable "namespace" {
  type        = string
  description = "Namespace for Forgejo resources"
  default     = "forgejo"
}

variable "domain" {
  type        = string
  description = "Domain name for Forgejo Ingress (e.g., git.carvin.cloud)"
}

variable "storage_size" {
  type        = string
  description = "Size of persistent storage for Forgejo data and repositories"
  default     = "100Gi"
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

variable "admin_password" {
  type        = string
  description = "Password for the Forgejo admin user (gitea_admin)"
  sensitive   = true
}

variable "admin_email" {
  type        = string
  description = "Email address for the Forgejo admin user"
  default     = ""
}
