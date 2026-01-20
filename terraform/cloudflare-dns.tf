# Cloudflare DNS Records (DNS-only, no proxy/tunnel)
# Creates A and AAAA records for all services, intended to be kept up to date by a DDNS updater.

# Get zone ID for the domain
data "cloudflare_zone" "main" {
  name = var.domain
}

locals {
  # Collect all subdomains from external_services
  external_service_subdomains = [
    for service in var.external_services : split(".", service.domain)[0]
  ]

  # Subdomains for deployed services (extracted from services.tf)
  deployed_service_subdomains = [
    "grafana",   # Monitoring module
    "git",       # Forgejo module (git.${var.domain})
    "bitwarden", # Vaultwarden module (bitwarden.${var.domain})
    "paperless", # Paperless NGX module (paperless.${var.domain})
  ]

  # Root domain (for @ record)
  root_domain = ["@"]

  # Combine all subdomains
  all_subdomains = concat(
    local.external_service_subdomains,
    local.deployed_service_subdomains,
    local.root_domain
  )

  # Create a set of unique subdomains
  unique_subdomains = toset(local.all_subdomains)

  # Fully-qualified domains for DDNS updater
  domains_fqdn = [
    for sub in local.unique_subdomains : sub == "@" ? var.domain : "${sub}.${var.domain}"
  ]
  domains_csv = join(",", local.domains_fqdn)
}

# Create A records (IPv4)
resource "cloudflare_record" "dns_a_records" {
  for_each = local.unique_subdomains

  zone_id         = data.cloudflare_zone.main.id
  allow_overwrite = true

  # Use @ for root domain, otherwise use the subdomain name
  name    = each.value
  type    = "A"
  content = var.ddns_bootstrap_ipv4
  proxied = false # DNS only (no Cloudflare proxy)

  # Format comment based on whether it's root domain or subdomain
  comment = each.value == "@" ? "Managed by Terraform for DDNS (A) - ${var.domain}" : "Managed by Terraform for DDNS (A) - ${each.value}.${var.domain}"

  ttl = 1 # Auto TTL (managed by Cloudflare)

  lifecycle {
    # DDNS updater owns the IP value; Terraform should not fight it.
    ignore_changes = [content, ttl]
  }
}

# Create AAAA records (IPv6)
resource "cloudflare_record" "dns_aaaa_records" {
  for_each = var.ddns_enable_ipv6 ? local.unique_subdomains : toset([])

  zone_id         = data.cloudflare_zone.main.id
  allow_overwrite = true

  name    = each.value
  type    = "AAAA"
  content = var.ddns_bootstrap_ipv6
  proxied = false

  comment = each.value == "@" ? "Managed by Terraform for DDNS (AAAA) - ${var.domain}" : "Managed by Terraform for DDNS (AAAA) - ${each.value}.${var.domain}"

  ttl = 1

  lifecycle {
    ignore_changes = [content, ttl]
  }
}

