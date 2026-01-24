variable "namespace" {
  type        = string
  description = "Namespace for Overseerr resources"
  default     = "streaming"
}

variable "domain" {
  type        = string
  description = "Domain name for Overseerr Ingress (e.g., overseerr.example.com)"
}

variable "local_domain" {
  type        = string
  description = "Local domain name for Ingress (e.g., homelab.local). Used for local network access with self-signed certificates"
  default     = ""
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

variable "storage_size" {
  type        = string
  description = "Size of persistent storage for Overseerr config"
  default     = "10Gi"
}

variable "time_zone" {
  type        = string
  description = "Time zone for Overseerr (e.g., Europe/Berlin)"
  default     = "Europe/Berlin"
}

variable "puid" {
  type        = number
  description = "User ID for file permissions inside the container"
  default     = 1000
}

variable "pgid" {
  type        = number
  description = "Group ID for file permissions inside the container"
  default     = 1000
}
