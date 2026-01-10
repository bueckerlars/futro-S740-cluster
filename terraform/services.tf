# Services Deployment
# Deploys various services to the Kubernetes cluster

# Monitoring service (Prometheus + Grafana)
module "monitoring" {
  source = "./modules/services/monitoring"

  grafana_admin_password = var.grafana_admin_password
  domain                 = var.domain
  local_domain            = var.local_domain

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
  local_domain            = var.local_domain

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
  local_domain = var.local_domain

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster,
    kubernetes_manifest.traefik_middleware
  ]
}

# Forgejo service (Git hosting platform)
module "forgejo" {
  source = "./modules/services/forgejo"

  domain         = "git.${var.domain}"
  local_domain   = var.local_domain
  storage_size   = "100Gi"
  admin_password = var.forgejo_admin_password
  admin_email    = var.forgejo_admin_email

  # Actions configuration
  actions_enabled = var.forgejo_actions_enabled
  runner_enabled  = var.forgejo_runner_enabled
  runner_token    = var.forgejo_runner_token
  runner_labels   = var.forgejo_runner_labels
  runner_replicas = var.forgejo_runner_replicas
  runner_name     = var.forgejo_runner_name

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster,
    kubernetes_manifest.traefik_middleware
  ]
}

