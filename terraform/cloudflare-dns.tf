# Cloudflare DNS Records for Tunnel
# Automatically creates CNAME records pointing to the Cloudflare Tunnel for all services

# Get zone ID for the domain
data "cloudflare_zone" "main" {
  name = var.domain
}

# Extract tunnel ID from tunnel token
# Tunnel token is base64 encoded JSON with structure: {"a":"account-id","t":"tunnel-id","s":"secret"}
locals {
  # Decode tunnel token to get tunnel ID
  tunnel_token_decoded = jsondecode(base64decode(var.cloudflare_tunnel_token))
  tunnel_id            = local.tunnel_token_decoded.t
  tunnel_target        = "${local.tunnel_id}.cfargotunnel.com"
  
  # Collect all subdomains from external_services
  external_service_subdomains = [
    for service in var.external_services : split(".", service.domain)[0]
  ]
  
  # Add grafana subdomain from monitoring module
  all_subdomains = concat(
    local.external_service_subdomains,
    ["grafana"]
  )
  
  # Create a set of unique subdomains
  unique_subdomains = toset(local.all_subdomains)
}

# Create CNAME records for each subdomain pointing to the tunnel
resource "cloudflare_record" "tunnel_subdomains" {
  for_each = local.unique_subdomains
  
  zone_id = data.cloudflare_zone.main.id
  name    = each.value
  type    = "CNAME"
  content = local.tunnel_target
  proxied = true  # Enable Cloudflare proxy (orange cloud)
  
  comment = "Managed by Terraform for Cloudflare Tunnel - ${each.value}.${var.domain}"
  
  ttl = 1  # Auto TTL (managed by Cloudflare)
}

