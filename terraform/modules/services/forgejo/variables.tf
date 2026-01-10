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

variable "actions_enabled" {
  type        = bool
  description = "Enable Forgejo Actions"
  default     = true
}

variable "runner_enabled" {
  type        = bool
  description = "Enable Forgejo Actions Runner deployment"
  default     = true
}

variable "runner_token" {
  type        = string
  description = "Registration token for Forgejo Actions Runner (get from Forgejo UI: Settings → Actions → Runners → Create new Runner)"
  sensitive   = true
  default     = ""
}

variable "runner_labels" {
  type        = list(string)
  description = "Labels for the Forgejo Actions Runner. Format: 'ubuntu-latest:docker://node:18-bullseye' or 'docker:docker://docker:dind'. Leave empty to use defaults."
  default     = []
}

variable "runner_replicas" {
  type        = number
  description = "Number of runner replicas"
  default     = 1
}

variable "runner_name" {
  type        = string
  description = "Name for the Forgejo Actions Runner"
  default     = ""
}
