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

variable "nfs_server" {
  type        = string
  description = "NFS server IP address or hostname"
  default     = "192.168.178.10"
}

variable "nfs_export_path" {
  type        = string
  description = "NFS export path"
  default     = "/mnt/SSD-Pool/k3s-storage"
}

variable "nfs_mount_options" {
  type        = string
  description = "NFS mount options"
  default     = "rw,sync,hard,intr"
}

variable "letsencrypt_email" {
  type        = string
  description = "Email address for Let's Encrypt certificate registration"
  default     = ""
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

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API Token for DNS management. Required for DNS-01 Challenge with Cloudflare. Create token at: https://dash.cloudflare.com/profile/api-tokens. Requires Zone:DNS:Edit permissions for the domain."
  sensitive   = true
}

variable "cloudflare_email" {
  type        = string
  description = "Cloudflare account email address. Required for DNS-01 Challenge with Cloudflare. This is your Cloudflare account email."
  default     = ""
}

variable "ddns_bootstrap_ipv4" {
  type        = string
  description = "Initial placeholder IPv4 for DNS-only A records. DDNS updater will replace this value."
  default     = "198.51.100.1"
}

variable "ddns_bootstrap_ipv6" {
  type        = string
  description = "Initial placeholder IPv6 for DNS-only AAAA records. DDNS updater will replace this value."
  default     = "2001:db8::1"
}

variable "ddns_enable_ipv6" {
  type        = bool
  description = "Whether to manage IPv6 (AAAA records) for external DNS. Disable if your cluster cannot detect public IPv6 reliably."
  default     = false
}

variable "grafana_admin_password" {
  type        = string
  description = "Admin password for Grafana"
  sensitive   = true
}

variable "traefik_middlewares" {
  type = map(object({
    headers = object({
      frameDeny               = optional(bool)
      sslRedirect             = optional(bool)
      browserXssFilter        = optional(bool)
      contentTypeNosniff      = optional(bool)
      forceSTSHeader          = optional(bool)
      stsIncludeSubdomains    = optional(bool)
      stsPreload              = optional(bool)
      stsSeconds              = optional(number)
      customFrameOptionsValue = optional(string)
      customRequestHeaders    = optional(map(string), {})
      customResponseHeaders   = optional(map(string), {})
    })
  }))
  description = "Map of reusable Traefik middlewares. Key is middleware name, value contains headers configuration"
  default     = {}
}

variable "external_services" {
  type = map(object({
    domain               = string
    ip                   = string
    port                 = number
    path                 = optional(string, "/")
    headers              = optional(map(string), {})
    middlewares          = optional(list(string), [])
    scheme               = optional(string, "http")
    insecure_skip_verify = optional(bool, false)
  }))
  description = "Map of external services to expose via Traefik. Key is service name, value contains domain, internal IP, port, path, optional custom headers (service-specific), optional middleware names (reusable), scheme (http/https), and insecure_skip_verify (for self-signed certificates)"
  default     = {}
}

variable "vaultwarden_admin_token" {
  type        = string
  description = "Admin token for Vaultwarden admin panel. Generate a secure random token (e.g., using openssl rand -base64 32)"
  sensitive   = true
}

variable "forgejo_admin_password" {
  type        = string
  description = "Password for the Forgejo admin user (gitea_admin)"
  sensitive   = true
}

variable "forgejo_admin_email" {
  type        = string
  description = "Email address for the Forgejo admin user"
  default     = ""
}

variable "forgejo_actions_enabled" {
  type        = bool
  description = "Enable Forgejo Actions"
  default     = true
}

variable "forgejo_runner_enabled" {
  type        = bool
  description = "Enable Forgejo Actions Runner deployment"
  default     = true
}

variable "forgejo_runner_token" {
  type        = string
  description = "Registration token for Forgejo Actions Runner. Get from Forgejo UI: Settings → Actions → Runners → Create new Runner"
  sensitive   = true
  default     = ""
}

variable "forgejo_runner_labels" {
  type        = list(string)
  description = "Labels for the Forgejo Actions Runner (e.g., kubernetes, docker)"
  default     = ["kubernetes"]
}

variable "forgejo_runner_replicas" {
  type        = number
  description = "Number of Forgejo Actions Runner replicas"
  default     = 1
}

variable "forgejo_runner_name" {
  type        = string
  description = "Name for the Forgejo Actions Runner"
  default     = ""
}

variable "paperless_secret_key" {
  type        = string
  description = "Secret key for Paperless NGX. If not provided, will be auto-generated"
  sensitive   = true
  default     = ""
}

variable "paperless_time_zone" {
  type        = string
  description = "Time zone for Paperless NGX (e.g., Europe/Berlin)"
  default     = "Europe/Berlin"
}

variable "paperless_ocr_language" {
  type        = string
  description = "Default OCR language for Paperless NGX (e.g., deu for German)"
  default     = "deu"
}

variable "paperless_ocr_languages" {
  type        = string
  description = "Additional OCR languages for Paperless NGX (space-separated, e.g., 'eng deu')"
  default     = "eng deu"
}

variable "paperless_storage_media_size" {
  type        = string
  description = "Size of persistent storage for Paperless NGX media volume"
  default     = "50Gi"
}

variable "paperless_storage_data_size" {
  type        = string
  description = "Size of persistent storage for Paperless NGX data volume"
  default     = "20Gi"
}

variable "paperless_storage_consume_size" {
  type        = string
  description = "Size of persistent storage for Paperless NGX consume volume"
  default     = "10Gi"
}

variable "paperless_storage_export_size" {
  type        = string
  description = "Size of persistent storage for Paperless NGX export volume"
  default     = "10Gi"
}

variable "paperless_storage_postgresql_size" {
  type        = string
  description = "Size of persistent storage for Paperless NGX PostgreSQL database"
  default     = "20Gi"
}

variable "paperless_admin_user" {
  type        = string
  description = "Username for the Paperless NGX admin user"
  default     = "admin"
}

variable "paperless_admin_password" {
  type        = string
  description = "Password for the Paperless NGX admin user"
  sensitive   = true
}

variable "collabora_admin_user" {
  type        = string
  description = "Admin username for Collabora Online admin console"
  default     = "admin"
}

variable "collabora_admin_password" {
  type        = string
  description = "Admin password for Collabora Online admin console"
  sensitive   = true
}

variable "collabora_wopi_domains" {
  type        = list(string)
  description = "List of allowed WOPI host domains for Collabora Online (e.g., [\"office.carvin.cloud\", \"nextcloud.carvin.cloud\"])"
  default     = []
}

variable "couchdb_admin_user" {
  type        = string
  description = "Admin username for CouchDB"
  default     = "admin"
}

variable "couchdb_admin_password" {
  type        = string
  description = "Admin password for CouchDB"
  sensitive   = true
}

variable "couchdb_storage_size" {
  type        = string
  description = "Size of persistent storage for CouchDB data"
  default     = "10Gi"
}

variable "streaming_puid" {
  type        = number
  description = "User ID for Tautulli/Overseerr container file permissions"
  default     = 1000
}

variable "streaming_pgid" {
  type        = number
  description = "Group ID for Tautulli/Overseerr container file permissions"
  default     = 1000
}

variable "streaming_time_zone" {
  type        = string
  description = "Time zone for Tautulli/Overseerr (e.g., Europe/Berlin)"
  default     = "Europe/Berlin"
}

variable "tautulli_storage_size" {
  type        = string
  description = "Size of persistent storage for Tautulli config"
  default     = "5Gi"
}

variable "overseerr_storage_size" {
  type        = string
  description = "Size of persistent storage for Overseerr config"
  default     = "10Gi"
}

