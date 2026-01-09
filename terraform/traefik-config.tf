# Traefik Configuration with Let's Encrypt
# Configures the built-in Traefik Ingress Controller in K3S to use Let's Encrypt for TLS certificates
# Uses HTTP Challenge (works with Cloudflare Tunnel as it provides public access)
# Also configures TLS Store for self-signed certificates for local domain access

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
  - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
%{if var.local_domain != ""}
  - "--providers.kubernetescrd.namespaces=default,kube-system"
%{endif}
EOT
    }
  }

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster
  ]
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

