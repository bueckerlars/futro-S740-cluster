# Services Deployment
# Deploys various services to the Kubernetes cluster

# Monitoring service (Prometheus + Grafana)
module "monitoring" {
  source = "./modules/services/monitoring"

  grafana_admin_password = var.grafana_admin_password
  domain                 = var.domain
  local_domain           = var.local_domain

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster,
    kubernetes_manifest.traefik_middleware,
    kubernetes_manifest.https_redirect
  ]
}

# External services (services running on other servers)
module "external_services" {
  source = "./modules/services/external-services"
  count  = length(var.external_services) > 0 ? 1 : 0

  services                 = var.external_services
  namespace                = "default"
  letsencrypt_certresolver = "letsencrypt"
  local_domain             = var.local_domain

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster,
    kubernetes_manifest.traefik_middleware,
    kubernetes_manifest.https_redirect
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
    kubernetes_manifest.traefik_middleware,
    kubernetes_manifest.https_redirect
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
    kubernetes_manifest.traefik_middleware,
    kubernetes_manifest.https_redirect
  ]
}

# Portainer Agent service (Kubernetes cluster management agent)
module "portainer_agent" {
  source = "./modules/services/portainer-agent"

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster
  ]
}

# Paperless NGX service (Document management system)
module "paperless" {
  source = "./modules/services/paperless"

  domain                  = "paperless.${var.domain}"
  local_domain            = var.local_domain
  nfs_server              = var.nfs_server
  secret_key              = var.paperless_secret_key
  time_zone               = var.paperless_time_zone
  ocr_language            = var.paperless_ocr_language
  ocr_languages           = var.paperless_ocr_languages
  admin_user              = var.paperless_admin_user
  admin_password          = var.paperless_admin_password
  storage_media_size      = var.paperless_storage_media_size
  storage_data_size       = var.paperless_storage_data_size
  storage_consume_size    = var.paperless_storage_consume_size
  storage_export_size     = var.paperless_storage_export_size
  storage_postgresql_size = var.paperless_storage_postgresql_size

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster,
    kubernetes_manifest.traefik_middleware,
    kubernetes_manifest.https_redirect
  ]
}

# Collabora Online service (Collaborative office suite)
module "collabora" {
  source = "./modules/services/collabora"

  domain         = "office.${var.domain}"
  local_domain   = var.local_domain
  admin_user     = var.collabora_admin_user
  admin_password = var.collabora_admin_password
  wopi_domains   = var.collabora_wopi_domains

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster,
    kubernetes_manifest.traefik_middleware,
    kubernetes_manifest.https_redirect
  ]
}

