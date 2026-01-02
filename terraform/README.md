# OpenTofu Configuration for Futro S740 K3s Cluster

This directory contains OpenTofu (Terraform-compatible) configuration for managing the cloud-init files and K3s cluster resources for the Futro S740 Kubernetes cluster.

## Structure

```
terraform/
├── main.tf                 # Root module with module calls
├── variables.tf            # Central variables
├── outputs.tf              # Outputs (IPs, hostnames, etc.)
├── providers.tf            # Provider configuration (k3s, local)
├── versions.tf             # Version constraints
├── terraform.tfvars.example # Example configuration
└── modules/
    ├── cloud-init/
    │   ├── master/         # Master node cloud-init module
    │   └── worker/         # Worker node cloud-init module
    └── k3s/                # K3s cluster resources module
```

## Prerequisites

- OpenTofu or Terraform >= 1.5.0
- K3s cluster already deployed (for K3s resource management)

## Usage

### 1. Initialize OpenTofu

```bash
cd terraform
tofu init
```

### 2. Configure Variables

Copy the example configuration file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values:
- Network configuration (subnet, gateway, DNS)
- Node IPs and hostnames
- SSH public keys
- K3s token (sensitive)
- User configuration

### 3. Generate Cloud-Init Files

Generate the cloud-init configuration files:

```bash
tofu plan
tofu apply
```

This will generate the cloud-init YAML files in `../configs/cloud-init/`:
- `k3s-master.yaml`
- `k3s-worker-1.yaml`
- `k3s-worker-2.yaml`
- `k3s-worker-3.yaml`

### 4. Use Generated Files

The generated cloud-init files can be used during Kairos installation:

```bash
kairos-agent install --cloud-init /path/to/k3s-master.yaml
```

## Modules

### Cloud-Init Modules

- **`modules/cloud-init/master`**: Generates the master node cloud-init configuration
- **`modules/cloud-init/worker`**: Generates worker node cloud-init configurations

Both modules use templates to generate the cloud-init YAML files based on the variables provided.

### K3s Module

- **`modules/k3s`**: Manages K3s cluster resources (namespaces, deployments, services, etc.)

This module requires the K3s cluster to be already running and accessible via the API endpoint.

## Variables

Key variables (see `variables.tf` for complete list):

- `network`: Network configuration (subnet, gateway, DNS servers, interface)
- `master_node`: Master node hostname and IP
- `worker_nodes`: List of worker node configurations
- `user`: User configuration (name, password hash, SSH keys, groups)
- `k3s`: K3s configuration (token, flannel backend, master IP)
- `k3s_api_endpoint`: K3s API endpoint for resource management
- `k3s_token`: K3s token for API access (sensitive)
- `install_device`: Installation device for Kairos (default: `/dev/sda`)
- `output_dir`: Directory where cloud-init files will be written

## Outputs

After applying, you can view outputs:

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

Example (uncomment in `modules/k3s/main.tf`):

```hcl
resource "k3s_namespace" "example" {
  metadata {
    name = "example"
  }
}
```

## Security Notes

- **Sensitive Variables**: K3s tokens and password hashes are marked as sensitive
- **SSH Keys**: Update SSH public keys in `terraform.tfvars` with your own keys
- **K3s Token**: The K3s token should be kept secure and not committed to version control
- **Password Hash**: Consider using a strong password and generating a new hash

## Troubleshooting

### Provider Not Found

If you get provider errors, ensure you've run `tofu init`:

```bash
tofu init -upgrade
```

### K3s Provider Connection Issues

If the K3s provider cannot connect:
- Verify the K3s cluster is running
- Check the API endpoint is correct
- Verify the token is valid
- Ensure network connectivity to the master node

### Cloud-Init File Generation

If files are not generated:
- Check the `output_dir` variable is correct
- Verify write permissions to the output directory
- Review Terraform logs for errors

## References

- [OpenTofu Documentation](https://opentofu.org/docs)
- [K3s Provider Documentation](https://registry.terraform.io/providers/k3s-io/k3s/latest/docs)
- [Kairos Documentation](https://kairos.io/docs/)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)

