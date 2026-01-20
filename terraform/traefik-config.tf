# Traefik Configuration with Let's Encrypt
# Configures the built-in Traefik Ingress Controller in K3S to use Let's Encrypt for TLS certificates
# Uses DNS-01 Challenge with Cloudflare (more reliable, avoids rate limits, works behind Cloudflare Tunnel)
# Also configures TLS Store for self-signed certificates for local domain access

# Use existing Cloudflare API Token Secret (created in cloudflare-secret.tf)

resource "kubernetes_manifest" "traefik_helmchartconfig" {
  manifest = {
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "traefik"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = <<-EOT
additionalArguments:
  - "--certificatesresolvers.letsencrypt.acme.email=${var.letsencrypt_email}"
  - "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
  - "--certificatesresolvers.letsencrypt.acme.dnschallenge=true"
  - "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=cloudflare"
  # Watch all namespaces for CRD resources (middlewares, ingressroutes, etc.)
  - "--providers.kubernetescrd.namespaces="

persistence:
  enabled: true
  existingClaim: traefik-acme
  path: /data

env:
  - name: CLOUDFLARE_DNS_API_TOKEN
    valueFrom:
      secretKeyRef:
        name: cloudflare-api-token
        key: CLOUDFLARE_DNS_API_TOKEN
  - name: CLOUDFLARE_EMAIL
    valueFrom:
      secretKeyRef:
        name: cloudflare-api-token
        key: CLOUDFLARE_EMAIL
EOT
    }
  }

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster,
    kubernetes_secret.cloudflare_api_token
  ]
}

# Persistent storage for Traefik ACME certificates on NFS
resource "kubernetes_persistent_volume_claim_v1" "traefik_acme" {
  metadata {
    name      = "traefik-acme"
    namespace = "kube-system"
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }

    storage_class_name = "nfs"
  }
}

# Kubernetes Secret for self-signed certificate (local domain)
# This secret contains the TLS certificate and key for the local domain
# The certificate must be created manually (see documentation)
resource "kubernetes_secret" "traefik_local_tls" {
  count = var.local_domain != "" ? 1 : 0

  metadata {
    name      = "traefik-local-tls"
    namespace = "kube-system"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = fileexists("${path.module}/certs/${var.local_domain}.crt") ? filebase64("${path.module}/certs/${var.local_domain}.crt") : base64encode("")
    "tls.key" = fileexists("${path.module}/certs/${var.local_domain}.key") ? filebase64("${path.module}/certs/${var.local_domain}.key") : base64encode("")
  }

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster
  ]

  lifecycle {
    ignore_changes = [data]
  }
}

# TLS Store for self-signed certificates (local domain)
# This allows Traefik to use self-signed certificates for the local domain
# Note: The default TLS store in kube-system namespace will use the secret above
resource "kubernetes_manifest" "traefik_tlsstore_local" {
  count = var.local_domain != "" ? 1 : 0

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "TLSStore"
    metadata = {
      name      = "default"
      namespace = "kube-system"
    }
    spec = {
      defaultCertificate = {
        secretName = "traefik-local-tls"
      }
    }
  }

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster,
    kubernetes_secret.traefik_local_tls
  ]
}

