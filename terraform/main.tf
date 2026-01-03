# Generate /etc/hosts entries for all nodes
locals {
  # Helper function to format worker hostnames with hyphen
  format_hostname = {
    for key, node in local.nodes :
    key => node.role == "master" ? "k3s-master" : "k3s-${replace(key, "worker", "worker-")}"
  }

  hosts_entries = join("\n", [
    for key, node in local.nodes :
    "${node.host} ${local.format_hostname[key]}"
  ])

  # Generate hostname for each node
  node_hostnames = local.format_hostname

  # Extract master IP from nodes
  master_ip = [
    for key, node in local.nodes :
    node.host
    if node.role == "master"
  ][0]
}

# Generate bootstrap cloud-init configs for each node
resource "local_file" "bootstrap_config" {
  for_each = local.nodes

  content = templatefile(
    "${path.module}/cloud-init/bootstrap.yaml.tpl",
    {
      node_ip        = each.value.host
      hostname       = local.node_hostnames[each.key]
      dns_server     = var.dns_server
      gateway        = var.gateway
      password_hash  = var.password_hash
      ssh_public_key = var.ssh_public_key
    }
  )

  filename             = "${path.module}/cloud-init/generated/bootstrap-${each.key}.yaml"
  file_permission      = "0644"
  directory_permission = "0755"
}

# Deploy Kairos config files to nodes and trigger reboot
# This resource only triggers when the content of config files changes (SHA256-based triggers)
resource "null_resource" "kairos_config_deploy" {
  for_each = local.nodes

  triggers = {
    # Hash of k3s config content (master or worker)
    k3s_config_hash = sha256(templatefile(
      each.value.role == "master"
      ? "${path.module}/cloud-init/k3s-master.yaml"
      : "${path.module}/cloud-init/k3s-worker.yaml",
      {
        NODE_IP   = each.value.host
        MASTER_IP = local.master_ip
        K3S_TOKEN = var.k3s_token
      }
    ))
    # Hash of NFS storage config content
    nfs_config_hash = sha256(templatefile(
      "${path.module}/cloud-init/nfs-storage.yaml",
      {
        NFS_SERVER      = var.nfs_server
        NFS_EXPORT_PATH = var.nfs_export_path
        NFS_MOUNT_OPTIONS = var.nfs_mount_options
      }
    ))
    # Hash of hosts entries
    hosts_hash = sha256(local.hosts_entries)
  }

  connection {
    type        = "ssh"
    host        = each.value.host
    user        = "kairos"
    private_key = file(pathexpand("~/.ssh/id_rsa"))
    timeout     = "2m"
  }

  # Copy k3s config to /tmp
  provisioner "file" {
    content = templatefile(
      each.value.role == "master"
      ? "${path.module}/cloud-init/k3s-master.yaml"
      : "${path.module}/cloud-init/k3s-worker.yaml",
      {
        NODE_IP   = each.value.host
        MASTER_IP = local.master_ip
        K3S_TOKEN = var.k3s_token
      }
    )
    destination = "/tmp/91_k3s.yaml"
  }

  # Copy NFS storage config to /tmp
  provisioner "file" {
    content = templatefile(
      "${path.module}/cloud-init/nfs-storage.yaml",
      {
        NFS_SERVER      = var.nfs_server
        NFS_EXPORT_PATH = var.nfs_export_path
        NFS_MOUNT_OPTIONS = var.nfs_mount_options
      }
    )
    destination = "/tmp/92_nfs-storage.yaml"
  }

  # Copy hosts entries to /tmp
  provisioner "file" {
    content     = local.hosts_entries
    destination = "/tmp/k3s-hosts-entries"
  }

  # Move files to /oem/, update /etc/hosts, and reboot
  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/91_k3s.yaml /oem/91_k3s.yaml",
      "sudo mv /tmp/92_nfs-storage.yaml /oem/92_nfs-storage.yaml",
      "sudo bash -c 'sed -i \"/# K3S cluster nodes/,/^$/d\" /etc/hosts || true'",
      "sudo bash -c 'echo \"\" >> /etc/hosts'",
      "sudo bash -c 'echo \"# K3S cluster nodes\" >> /etc/hosts'",
      "sudo bash -c 'cat /tmp/k3s-hosts-entries >> /etc/hosts'",
      "rm -f /tmp/k3s-hosts-entries",
      "sudo nohup sh -c 'sleep 5 && reboot' > /dev/null 2>&1 &"
    ]
  }
}

