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

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API Token for DNS management. Required for HTTP-01 Challenge with Cloudflare. Create token at: https://dash.cloudflare.com/profile/api-tokens. Requires Zone:DNS:Edit permissions for the domain."
  sensitive   = true
}

variable "cloudflare_tunnel_token" {
  type        = string
  description = "Cloudflare Tunnel Token for cloudflared. Create token in Cloudflare Dashboard > Zero Trust > Tunnel > Create Tunnel > Token"
  sensitive   = true
}

variable "grafana_admin_password" {
  type        = string
  description = "Admin password for Grafana"
  sensitive   = true
}

variable "traefik_middlewares" {
  type = map(object({
    headers = object({
      frameDeny                = optional(bool)
      sslRedirect              = optional(bool)
      browserXssFilter         = optional(bool)
      contentTypeNosniff       = optional(bool)
      forceSTSHeader           = optional(bool)
      stsIncludeSubdomains     = optional(bool)
      stsPreload               = optional(bool)
      stsSeconds               = optional(number)
      customFrameOptionsValue  = optional(string)
      customRequestHeaders     = optional(map(string), {})
      customResponseHeaders    = optional(map(string), {})
    })
  }))
  description = "Map of reusable Traefik middlewares. Key is middleware name, value contains headers configuration"
  default     = {}
}

variable "external_services" {
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
  description = "Map of external services to expose via Traefik. Key is service name, value contains domain, internal IP, port, path, optional custom headers (service-specific), optional middleware names (reusable), scheme (http/https), and insecure_skip_verify (for self-signed certificates)"
  default     = {}
}

variable "vaultwarden_admin_token" {
  type        = string
  description = "Admin token for Vaultwarden admin panel. Generate a secure random token (e.g., using openssl rand -base64 32)"
  sensitive   = true
}

