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

