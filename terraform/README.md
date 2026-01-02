# OpenTofu Configuration for Futro S740 K3s Cluster

This directory contains OpenTofu (Terraform-compatible) configuration for managing the cloud-init files and K3s cluster resources for the Futro S740 Kubernetes cluster.

## Quick Start

1. **Initialize OpenTofu**:
   ```bash
   cd terraform
   tofu init
   ```

2. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your configuration
   ```

3. **Generate cloud-init files**:
   ```bash
   tofu plan
   tofu apply
   ```

4. **Follow the complete setup guide**: See [setup.md](setup.md) for detailed step-by-step instructions.

## What This Configuration Does

This OpenTofu setup provides:

- **Cloud-Init File Generation**: Dynamically generates cloud-init YAML files for master and worker nodes from templates
- **Centralized Configuration**: All cluster settings managed through `terraform.tfvars`
- **K3s Resource Management**: Optional management of K3s cluster resources (namespaces, deployments, services, etc.)

## Structure

```
terraform/
├── main.tf                 # Root module with module calls
├── variables.tf            # Central variables
├── outputs.tf              # Outputs (IPs, hostnames, etc.)
├── providers.tf            # Provider configuration (k3s, local)
├── versions.tf             # Version constraints
├── terraform.tfvars.example # Example configuration
├── setup.md                # Complete setup guide
└── modules/
    ├── cloud-init/
    │   ├── master/         # Master node cloud-init module
    │   └── worker/         # Worker node cloud-init module
    └── k3s/                # K3s cluster resources module
```

## Prerequisites

- OpenTofu or Terraform >= 1.5.0
- SSH key pair (for node access)
- Password hash for the kairos user
- K3s token (retrieved after master node installation)

## Configuration

### Key Variables

- `network`: Network configuration (subnet, gateway, DNS servers, interface)
- `master_node`: Master node hostname and IP address
- `worker_nodes`: List of worker node configurations (hostname and IP)
- `user`: User configuration (name, password hash, SSH keys, groups)
- `k3s`: K3s configuration (token, flannel backend, master IP)
- `k3s_api_endpoint`: K3s API endpoint for resource management
- `k3s_token`: K3s token for API access (sensitive)
- `install_device`: Installation device for Kairos (default: `/dev/sda`)
- `output_dir`: Directory where cloud-init files will be written

See `terraform.tfvars.example` for a complete example configuration.

### Getting the K3s Token

After installing the master node, retrieve the K3s token:

```bash
ssh kairos@<master-ip>
sudo cat /var/lib/rancher/k3s/server/node-token
```

Update `terraform.tfvars` with the token and regenerate cloud-init files:

```bash
tofu apply
```

## Modules

### Cloud-Init Modules

- **`modules/cloud-init/master`**: Generates the master node cloud-init configuration
- **`modules/cloud-init/worker`**: Generates worker node cloud-init configurations

Both modules use templates to generate the cloud-init YAML files based on the variables provided. The generated files are written to `../configs/cloud-init/`.

### K3s Module

- **`modules/k3s`**: Manages K3s cluster resources (namespaces, deployments, services, etc.)

This module requires the K3s cluster to be already running and accessible via the API endpoint configured in `k3s_api_endpoint`.

## Outputs

After applying, view outputs:

```bash
tofu output
```

Available outputs:
- `cloud_init_files`: Paths to generated cloud-init files
- `master_node`: Master node information
- `worker_nodes`: Worker nodes information
- `k3s_api_endpoint`: K3s API endpoint
- `cluster_nodes`: All cluster nodes with their IPs

## K3s Resource Management

The K3s module can be extended to manage cluster resources. Edit `modules/k3s/main.tf` or `modules/k3s/resources.tf` to add:

- Namespaces
- Deployments
- Services
- ConfigMaps
- Secrets
- etc.

Example:

```hcl
resource "k3s_namespace" "example" {
  metadata {
    name = "example"
  }
}
```

## Workflow

1. **Initial Setup**: Configure `terraform.tfvars` with your network settings, SSH keys, and password hash
2. **Generate Cloud-Init Files**: Run `tofu apply` to generate cloud-init files
3. **Install Master Node**: Use the generated `k3s-master.yaml` to install the master node
4. **Get K3s Token**: Retrieve the token from the master node
5. **Update Configuration**: Update `terraform.tfvars` with the real K3s token
6. **Regenerate Files**: Run `tofu apply` again to update worker configurations
7. **Install Worker Nodes**: Use the generated worker cloud-init files
8. **Manage Resources**: Optionally use the K3s module to manage cluster resources

For detailed step-by-step instructions, see [setup.md](setup.md).

## Troubleshooting

### Provider Not Found

```bash
tofu init -upgrade
```

### K3s Provider Connection Issues

- Verify the K3s cluster is running
- Check the API endpoint is correct: `curl -k https://<master-ip>:6443`
- Verify the token is correct (from `/var/lib/rancher/k3s/server/node-token`)
- Check network connectivity

### Cloud-Init File Generation

- Verify `output_dir` variable is correct
- Check write permissions: `ls -ld ../configs/cloud-init`
- Review OpenTofu logs for errors

### K3s Logs

**Master node (server):**
```bash
sudo tail -n 100 /var/log/k3s.log
sudo tail -f /var/log/k3s.log
```

**Worker nodes (agent):**
```bash
sudo tail -n 100 /var/log/k3s-agent.log
sudo tail -f /var/log/k3s-agent.log
```

For more troubleshooting information, see the [Troubleshooting section in setup.md](setup.md#troubleshooting).

## Security Notes

- **Never commit `terraform.tfvars`** - it contains sensitive data (tokens, password hashes)
- **Use strong passwords** for the kairos user
- **Keep SSH keys secure** - don't share private keys
- **Rotate K3s tokens** periodically in production environments
- **Consider firewall rules** to restrict access to the cluster

## References

- [Complete Setup Guide](setup.md) - Step-by-step cluster setup instructions
- [OpenTofu Documentation](https://opentofu.org/docs)
- [K3s Provider Documentation](https://registry.terraform.io/providers/k3s-io/k3s/latest/docs)
- [Kairos Documentation](https://kairos.io/docs/)
- [K3s Documentation](https://docs.k3s.io/)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
