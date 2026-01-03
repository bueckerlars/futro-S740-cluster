# NFS Provisioner Configuration
# Installs nfs-subdir-external-provisioner to enable dynamic NFS volume provisioning

# Fetch kubeconfig from master node
# k3s stores kubeconfig at /etc/rancher/k3s/k3s.yaml on the master node
resource "null_resource" "kubeconfig" {
  depends_on = [
    ssh_resource.verify_node_online
  ]

  triggers = {
    master_ip = local.master_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ~/.kube
      ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no kairos@${local.master_ip} \
        "sudo cat /etc/rancher/k3s/k3s.yaml" | \
        sed "s/127.0.0.1/${local.master_ip}/g" > ~/.kube/config
      chmod 600 ~/.kube/config
    EOT
  }
}

# Wait for cluster to be ready before installing provisioner
# This ensures k3s API is accessible
resource "time_sleep" "wait_for_cluster" {
  depends_on = [
    ssh_resource.verify_node_online,
    null_resource.kubeconfig
  ]

  create_duration = "30s"
}

# Install NFS Subdir External Provisioner via Helm
resource "helm_release" "nfs_provisioner" {
  name       = "nfs-subdir-external-provisioner"
  repository = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner"
  chart      = "nfs-subdir-external-provisioner"
  version    = "4.0.18"
  namespace  = "kube-system"

  depends_on = [
    time_sleep.wait_for_cluster
  ]

  set {
    name  = "nfs.server"
    value = var.nfs_server
  }

  set {
    name  = "nfs.path"
    value = var.nfs_export_path
  }

  set {
    name  = "storageClass.name"
    value = "nfs"
  }

  set {
    name  = "storageClass.defaultClass"
    value = "true"
  }

  set {
    name  = "storageClass.reclaimPolicy"
    value = "Retain"
  }

  set {
    name  = "storageClass.pathPattern"
    value = "$${.PVC.namespace}/$${.PVC.name}"
  }
}

# Note: StorageClass is automatically created by the Helm chart
# with the name "nfs" and marked as default class

