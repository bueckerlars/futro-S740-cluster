variable "namespace" {
  type        = string
  description = "Namespace for Collabora Online resources"
  default     = "collabora"
}

variable "domain" {
  type        = string
  description = "Domain name for Collabora Online Ingress (e.g., office.carvin.cloud)"
}

variable "local_domain" {
  type        = string
  description = "Local domain name for Ingress (e.g., homelab.local). Used for local network access with self-signed certificates"
  default     = ""
}

variable "admin_user" {
  type        = string
  description = "Admin username for Collabora Online admin console"
  default     = "admin"
}

variable "admin_password" {
  type        = string
  description = "Admin password for Collabora Online admin console"
  sensitive   = true
}

variable "wopi_domains" {
  type        = list(string)
  description = "List of allowed WOPI host domains (e.g., [\"office.carvin.cloud\", \"nextcloud.carvin.cloud\"])"
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
