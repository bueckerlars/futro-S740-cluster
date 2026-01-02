# Terraform/OpenTofu Configuration for K3S Cluster

This directory contains the Terraform/OpenTofu configuration for managing the K3S Kubernetes cluster on Futro S740 nodes using Kairos OS.

## Overview

This configuration automates the setup and management of:
- Bootstrap cloud-init configurations for initial node installation
- Kairos/k3s configuration files on each node
- `/etc/hosts` entries for cluster node resolution
- NFS storage mounts for shared persistent volumes
- Automatic node reboots when Kairos configuration changes

## Prerequisites

### Required Software

- **OpenTofu** (>= 1.5.0) or **Terraform** (>= 1.0.0)
  - Installation: [OpenTofu Installation Guide](https://opentofu.org/docs/intro/install/)
  - Verify: `tofu version` or `terraform version`

### Required Access

- SSH access to all cluster nodes as user `kairos`
- SSH private key at `~/.ssh/id_rsa` (or update paths in `main.tf`)
- Network access to all node IP addresses

### Required Information

Before starting, you need:
- IP addresses of all cluster nodes
- K3S token (from master node or generate new one)
- Password hash for the `kairos` user
- SSH public key for the `kairos` user
- NFS server IP address and export path (optional, has defaults)

## Configuration

All configuration is done through variables in `terraform.tfvars`. 

**See `terraform.tfvars.example` for a complete example with all available variables and detailed explanations.**

To get started:
1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Fill in your actual values
3. **Important**: `terraform.tfvars` contains sensitive data and is git-ignored

## Usage

### Initial Setup

1. **Initialize OpenTofu/Terraform**
   ```bash
   cd terraform
   tofu init
   # or: terraform init
   ```

2. **Configure Variables**
   - Copy `terraform.tfvars.example` to `terraform.tfvars`
   - Edit `terraform.tfvars` with your actual values
   - **Important**: `terraform.tfvars` contains sensitive data and is git-ignored

3. **Review Plan**
   ```bash
   tofu plan
   # or: terraform plan
   ```
   This shows what changes will be made without applying them.

4. **Apply Configuration**
   ```bash
   tofu apply
   # or: terraform apply
   ```
   Review the plan and type `yes` to apply.

### Daily Operations

#### Update Configuration

1. Edit `terraform.tfvars` or other configuration files
2. Review changes: `tofu plan`
3. Apply changes: `tofu apply`

#### View Current State

```bash
tofu show
# or: terraform show
```

#### View Outputs

```bash
tofu output
# or: terraform output
```

#### Destroy Resources

⚠️ **Warning**: This will remove all configurations from nodes!

```bash
tofu destroy
# or: terraform destroy
```

## Important Concepts

### Reboot Behavior

**Nodes reboot automatically when Kairos/k3s configuration or NFS storage configuration changes.**

- ✅ **Reboot happens** when:
  - K3S configuration (`/oem/91_k3s.yaml`) is updated
  - K3S token changes
  - Master IP changes
  - Node role configuration changes
  - NFS storage configuration (`/oem/92_nfs-storage.yaml`) is updated
  - NFS server or export path changes
  - `/etc/hosts` entries change

- ❌ **Reboot does NOT happen** when:
  - Only unrelated configuration changes are made
  - `tofu apply` is run without any config changes

This ensures nodes reboot when necessary for configuration changes to take effect.

### Resource Dependencies

The configuration uses explicit dependencies to ensure correct execution order:

1. `local_file.bootstrap_config` - Generates bootstrap cloud-init files
2. `ssh_resource.kairos_config` - Deploys k3s configuration to nodes
3. `ssh_resource.nfs_storage_config` - Deploys NFS storage configuration to nodes
4. `ssh_resource.hosts_file` - Updates `/etc/hosts` on all nodes
5. `ssh_resource.reboot` - Reboots nodes when config changes are detected

### Hostname Format

- Master nodes: `k3s-master`
- Worker nodes: `k3s-worker-{number}` (e.g., `k3s-worker-1`, `k3s-worker-3`)
- Format is automatically generated from node keys in `terraform.tfvars`

### NFS Storage Configuration

The configuration automatically sets up NFS storage mounts on all nodes and installs an NFS provisioner for dynamic volume provisioning:

- **Mount Point**: `/var/lib/k3s/storage` (standard k3s persistent volume path)
- **NFS Server**: Configurable via `nfs_server` variable (default: `192.168.178.10`)
- **Export Path**: Configurable via `nfs_export_path` variable (default: `/mnt/SSD-Pool/k3s-storage`)
- **Mount Options**: Configurable via `nfs_mount_options` variable (default: `rw,sync,hard,intr`)
- **Persistence**: Mount is added to `/etc/fstab` for automatic mounting on boot
- **Scope**: Applied to all nodes (master and worker)

The NFS configuration is deployed as `/oem/92_nfs-storage.yaml` on each node and applied on the next reboot.

### NFS Provisioner

An NFS provisioner (`nfs-subdir-external-provisioner`) is automatically installed via Helm to enable dynamic volume provisioning:

- **StorageClass**: `nfs` (set as default storage class)
- **Provisioner**: `nfs-subdir-external-provisioner`
- **Namespace**: `kube-system`
- **Reclaim Policy**: `Retain` (volumes are not deleted when PVC is removed)
- **Path Pattern**: `${.PVC.namespace}/${.PVC.name}` (organized structure on NFS)

**Benefits**:
- Pods can move between nodes while maintaining access to their volumes
- All persistent volumes are stored on the shared NFS storage
- Volumes are automatically created when PVCs are created
- No manual volume management required

**Usage**: Simply create a PVC without specifying a storage class, and it will automatically use the NFS storage:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  # storageClassName: nfs  # Optional, nfs is the default
```

### Generated Files

- Bootstrap configs are generated in `cloud-init/generated/`
- These files are git-ignored and regenerated on each `tofu apply`
- They can be used for initial node installation via cloud-init

## Troubleshooting

### SSH Connection Issues

**Problem**: Cannot connect to nodes via SSH

**Solutions**:
- Verify SSH key is correct: `ssh -i ~/.ssh/id_rsa kairos@<node-ip>`
- Check if nodes are online: `ping <node-ip>`
- Verify SSH key path in `main.tf` (default: `~/.ssh/id_rsa`)
- Check firewall rules

### Provider Errors

**Problem**: Provider initialization fails

**Solutions**:
- Run `tofu init -upgrade` to update providers
- Check network connectivity
- Verify provider versions in `providers.tf`

### State File Issues

**Problem**: State file is out of sync

**Solutions**:
- Review state: `tofu show`
- Refresh state: `tofu refresh`
- If corrupted, may need to import resources: `tofu import`

### Reboot Not Happening

**Problem**: Nodes don't reboot after config changes

**Check**:
- Verify kairos_config resource changed: `tofu plan` should show changes
- Check if reboot resource has dependency on kairos_config
- Manually verify: `ssh kairos@<node> "sudo reboot"`

### K3S Configuration Not Applied

**Problem**: Changes to k3s config don't take effect

**Solutions**:
- Verify file was deployed: `ssh kairos@<node> "cat /oem/91_k3s.yaml"`
- Check if node rebooted (Kairos applies config on boot)
- Manually trigger reboot if needed
- Check Kairos logs: `ssh kairos@<node> "journalctl -u kairos"`

### NFS Storage Issues

**Problem**: NFS mount not working or not persistent

**Solutions**:
- Verify NFS server is accessible: `ping <nfs-server-ip>`
- Check if NFS client is installed: `ssh kairos@<node> "apk list | grep nfs-utils"`
- Verify mount point exists: `ssh kairos@<node> "ls -la /var/lib/k3s/storage"`
- Check fstab entry: `ssh kairos@<node> "cat /etc/fstab | grep k3s-storage"`
- Test manual mount: `ssh kairos@<node> "sudo mount -t nfs <nfs-server>:<export-path> /var/lib/k3s/storage"`
- Check NFS server export permissions and network connectivity
- Verify NFS config file: `ssh kairos@<node> "cat /oem/92_nfs-storage.yaml"`
- Check mount status: `ssh kairos@<node> "mount | grep k3s-storage"`

### NFS Provisioner Issues

**Problem**: PVCs are not being created or volumes are not accessible

**Solutions**:
- Check if NFS provisioner is running: `kubectl get pods -n kube-system | grep nfs`
- Verify StorageClass exists: `kubectl get storageclass nfs`
- Check if StorageClass is default: `kubectl get storageclass nfs -o yaml | grep is-default-class`
- View provisioner logs: `kubectl logs -n kube-system -l app=nfs-subdir-external-provisioner`
- Verify NFS server connectivity from cluster: `kubectl run -it --rm debug --image=busybox --restart=Never -- sh -c "ping <nfs-server-ip>"`
- Check PVC status: `kubectl get pvc`
- Check PV status: `kubectl get pv`
- Verify NFS export path permissions on NFS server
- Check if Helm release is installed: `helm list -n kube-system | grep nfs`
- Reinstall provisioner if needed: Update `nfs-provisioner.tf` and run `tofu apply`

## Extending the Configuration

### Adding New Nodes

1. Add node to `nodes` map in `terraform.tfvars`:
   ```hcl
   worker4 = {
     host = "192.168.178.19"
     role = "worker"
   }
   ```

2. Run `tofu plan` to see changes
3. Run `tofu apply` to add the node

### Modifying Cloud-Init Templates

1. Edit templates in `cloud-init/`:
   - `bootstrap.yaml.tpl` - Initial installation config
   - `k3s-master.yaml` - Master node k3s config
   - `k3s-worker.yaml` - Worker node k3s config
   - `nfs-storage.yaml` - NFS storage mount configuration

2. Templates use Terraform template syntax: `${variable_name}`
3. Changes require `tofu apply` to regenerate configs
4. NFS storage config is deployed to `/oem/92_nfs-storage.yaml` on all nodes

### Adding New Resources

1. Add resource definition to `main.tf`
2. Use `for_each = local.nodes` to apply to all nodes
3. Use `depends_on` for execution order if needed
4. Run `tofu plan` to verify

### Using Modules

The `modules/k3s/` directory is prepared for future module-based organization. To use:

1. Create module in `modules/k3s/`
2. Reference in `main.tf`:
   ```hcl
   module "k3s_cluster" {
     source = "./modules/k3s"
     # ... module variables
   }
   ```

## Best Practices

1. **Always review plan**: Run `tofu plan` before `tofu apply`
2. **Version control**: Commit `.tf` files, never commit `terraform.tfvars` or state files
3. **Backup state**: State files contain sensitive information - backup regularly
4. **Use workspaces**: For multiple environments, consider Terraform workspaces
5. **Document changes**: Update this README when adding new features

## Security Notes

- `terraform.tfvars` contains sensitive data (tokens, password hashes) - never commit
- State files may contain sensitive information - keep secure
- SSH keys should have proper permissions: `chmod 600 ~/.ssh/id_rsa`
- Use environment variables for sensitive values in CI/CD:
  ```bash
  export TF_VAR_k3s_token="..."
  export TF_VAR_password_hash="..."
  ```

## Additional Resources

- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Kairos Documentation](https://kairos.io/)
- [K3S Documentation](https://k3s.io/)

## Support

For issues specific to this configuration, check:
- Project main README: `../README.md`
- Terraform/OpenTofu logs: Check terminal output
- Node logs: SSH into nodes and check system logs

