# Services Deployment
# Deploys various services to the Kubernetes cluster

# Monitoring service (Prometheus + Grafana)
module "monitoring" {
  source = "./modules/services/monitoring"

  master_ip              = local.master_ip
  prometheus_nodeport    = 30909
  grafana_nodeport       = 30300
  grafana_admin_password = var.grafana_admin_password
  domain                 = var.domain

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster
  ]
}

# External services (services running on other servers)
module "external_services" {
  source = "./modules/services/external-services"
  count  = length(var.external_services) > 0 ? 1 : 0

  services                = var.external_services
  namespace               = "default"
  letsencrypt_certresolver = "letsencrypt"

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster,
    kubernetes_manifest.traefik_middleware
  ]
}

# Vaultwarden service (Bitwarden-compatible password manager)
module "vaultwarden" {
  source = "./modules/services/vaultwarden"

  domain       = "bitwarden.${var.domain}"
  admin_token  = var.vaultwarden_admin_token

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster,
    kubernetes_manifest.traefik_middleware
  ]
}

