variable "namespace" {
  type        = string
  description = "Namespace for Paperless NGX resources"
  default     = "paperless"
}

variable "domain" {
  type        = string
  description = "Domain name for Paperless NGX Ingress (e.g., paperless.carvin.cloud)"
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

variable "nfs_server" {
  type        = string
  description = "NFS server IP address or hostname for media volume"
}

variable "secret_key" {
  type        = string
  description = "Secret key for Paperless NGX. If not provided, will be auto-generated"
  sensitive   = true
  default     = ""
}

variable "time_zone" {
  type        = string
  description = "Time zone for Paperless NGX (e.g., Europe/Berlin)"
  default     = "Europe/Berlin"
}

variable "ocr_language" {
  type        = string
  description = "Default OCR language (e.g., deu for German)"
  default     = "deu"
}

variable "ocr_languages" {
  type        = string
  description = "Additional OCR languages (space-separated, e.g., 'eng deu')"
  default     = "eng deu"
}

variable "storage_media_size" {
  type        = string
  description = "Size of persistent storage for Paperless NGX media volume"
  default     = "50Gi"
}

variable "storage_data_size" {
  type        = string
  description = "Size of persistent storage for Paperless NGX data volume"
  default     = "20Gi"
}

variable "storage_consume_size" {
  type        = string
  description = "Size of persistent storage for Paperless NGX consume volume"
  default     = "10Gi"
}

variable "storage_export_size" {
  type        = string
  description = "Size of persistent storage for Paperless NGX export volume"
  default     = "10Gi"
}

variable "admin_user" {
  type        = string
  description = "Username for the Paperless NGX admin user"
  default     = "admin"
}

variable "admin_password" {
  type        = string
  description = "Password for the Paperless NGX admin user"
  sensitive   = true
}

