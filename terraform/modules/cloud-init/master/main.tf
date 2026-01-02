locals {
  output_file = "${var.output_dir}/k3s-master.yaml"
}

resource "local_file" "cloud_init" {
  content = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    hostname       = var.hostname
    ip_address     = var.ip_address
    network        = var.network
    user           = var.user
    k3s            = var.k3s
    install_device = var.install_device
    worker_nodes   = var.worker_nodes
  })

  filename             = local.output_file
  file_permission      = "0644"
  directory_permission = "0755"
}

output "output_file" {
  description = "Path to the generated cloud-init file"
  value       = local.output_file
}

