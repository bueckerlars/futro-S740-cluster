variable "namespace" {
  type        = string
  description = "Namespace for CouchDB resources"
  default     = "couchdb"
}

variable "domain" {
  type        = string
  description = "Domain name for CouchDB Ingress (e.g., couchdb.carvin.cloud)"
}

variable "local_domain" {
  type        = string
  description = "Local domain name for Ingress (e.g., homelab.local). Used for local network access with self-signed certificates"
  default     = ""
}

variable "admin_user" {
  type        = string
  description = "Admin username for CouchDB"
  default     = "admin"
}

variable "admin_password" {
  type        = string
  description = "Admin password for CouchDB"
  sensitive   = true
}

variable "storage_size" {
  type        = string
  description = "Size of persistent storage for CouchDB data"
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
