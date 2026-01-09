# External Services Module

This module creates Kubernetes Services and Ingress resources for services running on external servers (outside the Kubernetes cluster). It uses Traefik as the Ingress Controller with automatic Let's Encrypt TLS certificates.

## Features

- **External Service Integration**: Expose services running on other servers via Traefik
- **Automatic TLS**: Let's Encrypt certificates are automatically requested and renewed
- **Reusable Middlewares**: Define middlewares once and reference them in multiple services
- **Service-Specific Headers**: Support for custom HTTP headers per service (when reusable middlewares aren't enough)
- **Flexible Paths**: Configure custom paths for each service

## Usage

### Step 1: Define Reusable Middlewares (in root variables)

```hcl
# In terraform.tfvars or variables
traefik_middlewares = {
  standard-headers = {
    headers = {
      "X-Forwarded-Proto" = "https"
      "X-Real-IP"         = "$remote_addr"
      "X-Forwarded-For"   = "$proxy_add_x_forwarded_for"
    }
  }
  
  nextcloud-headers = {
    headers = {
      "X-Forwarded-Proto" = "https"
      "X-Forwarded-Host"  = "$host"
    }
  }
}
```

### Step 2: Use Services with Middleware References

```hcl
module "external_services" {
  source = "./modules/services/external-services"

  services = {
    # Service using reusable middleware
    nextcloud = {
      domain      = "nextcloud.<your-domain>"
      ip          = "<external-server-ip>"
      port        = 80
      path        = "/"
      middlewares = ["standard-headers", "nextcloud-headers"]
    }
    
    # Service with service-specific headers (not reusable)
    api = {
      domain  = "api.<your-domain>"
      ip      = "<external-server-ip>"
      port    = 3000
      path    = "/api"
      headers = {
        "Authorization" = "Bearer token123"
      }
    }
    
    # Service using both reusable middleware and service-specific headers
    webapp = {
      domain      = "webapp.<your-domain>"
      ip          = "<external-server-ip>"
      port        = 8080
      path        = "/"
      middlewares = ["standard-headers"]
      headers = {
        "X-Custom-Header" = "custom-value"
      }
    }
  }
  
  namespace               = "default"
  letsencrypt_certresolver = "letsencrypt"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| services | Map of external services. Each service requires domain, ip, port, optional path, and optional headers | `map(object)` | n/a | yes |
| namespace | Kubernetes namespace for the services | `string` | `"default"` | no |
| letsencrypt_certresolver | Name of the Let's Encrypt cert resolver | `string` | `"letsencrypt"` | no |

## Service Object Structure

Each service in the `services` map must have the following structure:

```hcl
{
  domain             = string              # Full domain name (e.g., "myapp.carvin.duckdns.org")
  ip                 = string              # Internal IP address of the external server
  port               = number              # Port number the service is listening on
  path               = optional(string)    # Path prefix (default: "/")
  headers            = optional(map(string)) # Service-specific custom HTTP headers (default: {})
  middlewares        = optional(list(string)) # List of reusable middleware names (default: [])
  scheme             = optional(string)     # Backend protocol: "http" or "https" (default: "http")
  insecure_skip_verify = optional(bool)    # Skip TLS verification for self-signed certificates (default: false)
}
```

**Note**: 
- You can use both `middlewares` (reusable) and `headers` (service-specific) together. The middlewares will be applied first, followed by service-specific headers.
- For services with self-signed certificates (e.g., Proxmox VE, TrueNAS), set `scheme = "https"` and `insecure_skip_verify = true` to avoid TLS verification errors.

## Outputs

| Name | Description |
|------|-------------|
| service_urls | Map of service names to their HTTPS URLs (all domains, e.g., `{ external = "https://service.example.com", local = "https://service.homelab.local" }`) |
| service_names | List of created service names |

## How It Works

1. **Endpoints**: Creates Kubernetes Endpoints pointing to the external server's IP and port
2. **Service**: Creates a ClusterIP Service that uses the Endpoints
3. **Ingress**: Creates a Traefik Ingress with TLS enabled
4. **Middleware**: If custom headers are specified, creates a Traefik Middleware for header injection

## Custom Headers

### Reusable Middlewares

Define middlewares once in `traefik_middlewares` and reference them in multiple services:

```hcl
traefik_middlewares = {
  standard-headers = {
    headers = {
      "X-Forwarded-Proto" = "https"
      "X-Real-IP"         = "$remote_addr"
      "X-Forwarded-For"   = "$proxy_add_x_forwarded_for"
    }
  }
}

external_services = {
  service1 = {
    domain      = "service1.<your-domain>"
    ip          = "<external-server-ip>"
    port        = 80
    middlewares = ["standard-headers"]  # Reuse the middleware
  }
  
  service2 = {
    domain      = "service2.<your-domain>"
    ip          = "<external-server-ip>"
    port        = 80
    middlewares = ["standard-headers"]  # Same middleware, no duplication!
  }
}
```

### Service-Specific Headers

For headers that are unique to a service (e.g., API keys, tokens), use the `headers` field:

```hcl
external_services = {
  api = {
    domain  = "api.<your-domain>"
    ip      = "<external-server-ip>"
    port    = 3000
    headers = {
      "Authorization" = "Bearer secret-token"
      "X-API-Key"     = "unique-key-for-this-service"
    }
  }
}
```

### Combining Both

You can use both reusable middlewares and service-specific headers:

```hcl
external_services = {
  webapp = {
    domain      = "webapp.<your-domain>"
    ip          = "<external-server-ip>"
    port        = 8080
    middlewares = ["standard-headers"]  # Reusable
    headers = {
      "X-Custom-Header" = "service-specific-value"  # Service-specific
    }
  }
}
```

### Services with Self-Signed Certificates

For services like Proxmox VE or TrueNAS that use self-signed certificates, you need to configure Traefik to skip TLS verification:

```hcl
external_services = {
  proxmox = {
    domain             = "pve.<your-domain>"
    ip                 = "<external-server-ip>"
    port               = 8006
    scheme             = "https"           # Use HTTPS for backend
    insecure_skip_verify = true            # Skip certificate verification
    middlewares        = ["standard-headers"]
  }
  
  truenas = {
    domain             = "truenas.<your-domain>"
    ip                 = "<external-server-ip>"
    port               = 443
    scheme             = "https"
    insecure_skip_verify = true
    middlewares        = ["standard-headers"]
  }
}
```

**How it works:**
1. A `ServersTransport` resource is created with `insecureSkipVerify: true`
2. The Ingress annotation `traefik.ingress.kubernetes.io/service.scheme` is set to `https`
3. The Ingress annotation `traefik.ingress.kubernetes.io/service.serversstransport` references the ServersTransport
4. Traefik will use HTTPS to communicate with the backend but won't verify the certificate

### Common Header Use Cases

- **X-Forwarded-Proto**: Set to "https" for services that need to know they're behind HTTPS
- **X-Real-IP**: Forward the real client IP address
- **X-Forwarded-For**: Forward the original client IP
- **X-Forwarded-Host**: Forward the original host header
- **Authorization**: Add authentication headers
- **Custom API Keys**: Add service-specific headers

## Requirements

- Traefik Ingress Controller (included in K3S)
- Let's Encrypt cert resolver configured in Traefik
- External services must be reachable from the Kubernetes cluster
- DNS records must point to your public IP (Port 80/443 forwarded to cluster)

