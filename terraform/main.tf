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

resource "ssh_resource" "kairos_config" {
  for_each = local.nodes

  host        = each.value.host
  user        = "kairos"
  private_key = file(pathexpand("~/.ssh/id_rsa"))
  timeout     = "2m"

  file {
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

    destination = "/oem/91_k3s.yaml"
  }
}

resource "ssh_resource" "hosts_file" {
  for_each = local.nodes

  host        = each.value.host
  user        = "kairos"
  private_key = file(pathexpand("~/.ssh/id_rsa"))
  timeout     = "2m"

  file {
    content     = local.hosts_entries
    destination = "/tmp/k3s-hosts-entries"
  }

  commands = [
    "sudo bash -c 'sed -i \"/# K3S cluster nodes/,/^$/d\" /etc/hosts || true'",
    "sudo bash -c 'echo \"\" >> /etc/hosts'",
    "sudo bash -c 'echo \"# K3S cluster nodes\" >> /etc/hosts'",
    "sudo bash -c 'cat /tmp/k3s-hosts-entries >> /etc/hosts'",
    "rm -f /tmp/k3s-hosts-entries"
  ]
}

# Reboot nodes after all configuration changes
# The reboot is triggered when kairos_config or hosts_file resources change
resource "ssh_resource" "reboot" {
  for_each = local.nodes

  depends_on = [
    ssh_resource.kairos_config,
    ssh_resource.hosts_file
  ]

  host        = each.value.host
  user        = "kairos"
  private_key = file(pathexpand("~/.ssh/id_rsa"))
  timeout     = "5m"

  # Reboot command - small delay ensures command is registered before connection drops
  commands = [
    "sleep 2 && sudo reboot"
  ]
}

