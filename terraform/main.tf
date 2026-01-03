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

  # Create hash triggers for reboot resource
  # This ensures reboot is triggered when kairos_config or hosts_file changes
  reboot_triggers = {
    for key, node in local.nodes :
    key => sha256(join("", [
      # Hash of kairos config content
      sha256(templatefile(
        node.role == "master"
        ? "${path.module}/cloud-init/k3s-master.yaml"
        : "${path.module}/cloud-init/k3s-worker.yaml",
        {
          NODE_IP   = node.host
          MASTER_IP = local.master_ip
          K3S_TOKEN = var.k3s_token
        }
      )),
      # Hash of hosts entries
      sha256(local.hosts_entries),
      # Hash of NFS storage config
      sha256(templatefile(
        "${path.module}/cloud-init/nfs-storage.yaml",
        {
          NFS_SERVER      = var.nfs_server
          NFS_EXPORT_PATH = var.nfs_export_path
          NFS_MOUNT_OPTIONS = var.nfs_mount_options
        }
      ))
    ]))
  }
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

# Deploy all Kairos configuration files to temp location first
# This allows us to check for changes before moving to /oem/ and triggering reboot
resource "ssh_resource" "nfs_storage_config_temp" {
  for_each = local.nodes

  host        = each.value.host
  user        = "kairos"
  private_key = file(pathexpand("~/.ssh/id_rsa"))
  timeout     = "10m"
  retry_delay = "10s"

  # Write to temp file
  file {
    content = templatefile(
      "${path.module}/cloud-init/nfs-storage.yaml",
      {
        NFS_SERVER      = var.nfs_server
        NFS_EXPORT_PATH = var.nfs_export_path
        NFS_MOUNT_OPTIONS = var.nfs_mount_options
      }
    )

    destination = "/tmp/92_nfs-storage.yaml.new"
  }

  commands = [
    "test -f /tmp/92_nfs-storage.yaml.new && echo 'NFS config temp file created' || exit 1"
  ]
}

resource "ssh_resource" "kairos_config_temp" {
  for_each = local.nodes

  depends_on = [
    ssh_resource.nfs_storage_config_temp
  ]

  host        = each.value.host
  user        = "kairos"
  private_key = file(pathexpand("~/.ssh/id_rsa"))
  timeout     = "10m"
  retry_delay = "10s"

  # Write to temp file
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

    destination = "/tmp/91_k3s.yaml.new"
  }

  commands = [
    "test -f /tmp/91_k3s.yaml.new && echo 'Kairos config temp file created' || exit 1"
  ]
}

# Deploy all config files atomically to /oem/ only if changes are detected
# This ensures only one reboot happens when all files are moved
resource "ssh_resource" "kairos_config" {
  for_each = local.nodes

  depends_on = [
    ssh_resource.kairos_config_temp,
    ssh_resource.hosts_file
  ]

  host        = each.value.host
  user        = "kairos"
  private_key = file(pathexpand("~/.ssh/id_rsa"))
  timeout     = "10m"
  retry_delay = "10s"

  # Check if files changed, then move all files atomically to /oem/
  # Kairos will automatically reboot once files are in /oem/
  commands = [
    <<-EOT
      # Check if any config files have changed
      CHANGED=false
      
      # Check kairos config
      if [ ! -f /oem/91_k3s.yaml ] || ! diff -q /tmp/91_k3s.yaml.new /oem/91_k3s.yaml >/dev/null 2>&1; then
        CHANGED=true
      fi
      
      # Check NFS storage config
      if [ ! -f /oem/92_nfs-storage.yaml ] || ! diff -q /tmp/92_nfs-storage.yaml.new /oem/92_nfs-storage.yaml >/dev/null 2>&1; then
        CHANGED=true
      fi
      
      # Only move files if changes were detected
      if [ "$CHANGED" = "true" ]; then
        echo "Configuration changes detected, deploying to /oem/..."
        sudo mv /tmp/91_k3s.yaml.new /oem/91_k3s.yaml
        sudo mv /tmp/92_nfs-storage.yaml.new /oem/92_nfs-storage.yaml
        echo "Files deployed. Kairos will reboot automatically."
      else
        echo "No configuration changes detected. Skipping deployment."
        rm -f /tmp/91_k3s.yaml.new /tmp/92_nfs-storage.yaml.new
      fi
      
      # Verify files exist
      test -f /oem/91_k3s.yaml && test -f /oem/92_nfs-storage.yaml && echo 'Files verified' || exit 1
    EOT
  ]
}

resource "ssh_resource" "hosts_file" {
  for_each = local.nodes

  host        = each.value.host
  user        = "kairos"
  private_key = file(pathexpand("~/.ssh/id_rsa"))
  timeout     = "10m"
  retry_delay = "10s"

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

# Wait for nodes to come back online after Kairos-triggered reboot (if reboot happened)
# Kairos automatically reboots when config files in /oem/ are changed
resource "time_sleep" "wait_after_reboot" {
  for_each = local.nodes

  depends_on = [
    ssh_resource.kairos_config
  ]

  create_duration = "120s"  # Wait 2 minutes for nodes to boot (if reboot occurred)
}

# Verify nodes are back online after reboot (if reboot happened)
resource "ssh_resource" "verify_node_online" {
  for_each = local.nodes

  depends_on = [
    time_sleep.wait_after_reboot
  ]

  host        = each.value.host
  user        = "kairos"
  private_key = file(pathexpand("~/.ssh/id_rsa"))
  timeout     = "5m"
  retry_delay = "10s"

  # Simple command to verify SSH connectivity and node is responsive
  # This will succeed even if no reboot happened (node is already online)
  commands = [
    "uptime",
    "echo 'Node ${each.key} is online'"
  ]
}

