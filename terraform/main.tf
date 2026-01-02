# Cloud-init configuration for master node
module "cloud_init_master" {
  source = "./modules/cloud-init/master"

  hostname       = var.master_node.hostname
  ip_address    = var.master_node.ip
  network        = var.network
  user           = var.user
  k3s            = var.k3s
  install_device = var.install_device
  worker_nodes   = var.worker_nodes
  output_dir     = var.output_dir
}

# Cloud-init configurations for worker nodes
module "cloud_init_workers" {
  source = "./modules/cloud-init/worker"

  for_each = {
    for idx, node in var.worker_nodes : node.hostname => node
  }

  hostname       = each.value.hostname
  ip_address     = each.value.ip
  network        = var.network
  user           = var.user
  k3s            = var.k3s
  install_device = var.install_device
  master_node    = var.master_node
  worker_nodes   = var.worker_nodes
  output_dir     = var.output_dir
}

# K3s cluster resources
module "k3s_cluster" {
  source = "./modules/k3s"

  k3s_api_endpoint = var.k3s_api_endpoint
  k3s_token        = var.k3s_token
}

