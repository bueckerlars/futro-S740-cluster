variable "services" {
  type = map(object({
    domain             = string
    ip                 = string
    port               = number
    path               = optional(string, "/")
    headers            = optional(map(string), {})
    middlewares        = optional(list(string), [])
    scheme             = optional(string, "http")
    insecure_skip_verify = optional(bool, false)
  }))
  description = "Map of external services to expose via Traefik. Supports both service-specific headers and reusable middleware references. Use scheme='https' and insecure_skip_verify=true for services with self-signed certificates (e.g., Proxmox, TrueNAS)"
}

variable "namespace" {
  type        = string
  description = "Namespace for external services"
  default     = "default"
}

variable "letsencrypt_certresolver" {
  type        = string
  description = "Name of the Let's Encrypt cert resolver"
  default     = "letsencrypt"
}

variable "local_domain" {
  type        = string
  description = "Local domain name for Ingress (e.g., homelab.local). Used for local network access with self-signed certificates"
  default     = ""
}

