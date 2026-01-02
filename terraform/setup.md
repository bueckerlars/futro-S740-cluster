# Complete Setup Guide: Futro S740 K3s Cluster

This guide will walk you through setting up your Futro S740 Kubernetes cluster from scratch using OpenTofu and Kairos.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Install OpenTofu](#step-1-install-opentofu)
3. [Step 2: Generate SSH Key](#step-2-generate-ssh-key)
4. [Step 3: Generate Password Hash](#step-3-generate-password-hash)
5. [Step 4: Configure OpenTofu](#step-4-configure-opentofu)
6. [Step 5: Generate Cloud-Init Files](#step-5-generate-cloud-init-files)
7. [Step 6: Install Master Node](#step-6-install-master-node)
8. [Step 7: Retrieve K3s Token from Master](#step-7-retrieve-k3s-token-from-master)
9. [Step 8: Update Configuration with K3s Token](#step-8-update-configuration-with-k3s-token)
10. [Step 9: Install Worker Nodes](#step-9-install-worker-nodes)
11. [Step 10: Verify Cluster](#step-10-verify-cluster)
12. [Step 11: Configure K3s Resource Management](#step-11-configure-k3s-resource-management)

---

## Prerequisites

Before starting, ensure you have:

- 4x Fujitsu Futro S740 devices
- Network switch and cables
- USB stick for Kairos installation
- A computer with internet access for running OpenTofu
- Basic knowledge of Linux command line

---

## Step 1: Install OpenTofu

Install OpenTofu on your local machine:

### macOS

```bash
brew install opentofu/tap/opentofu
```

### Linux

```bash
# Download and install OpenTofu
wget https://github.com/opentofu/opentofu/releases/latest/download/tofu_linux_amd64.zip
unzip tofu_linux_amd64.zip
sudo mv tofu /usr/local/bin/
sudo chmod +x /usr/local/bin/tofu
```

### Verify Installation

```bash
tofu version
```

You should see OpenTofu version information.

---

## Step 2: Generate SSH Key

If you don't already have an SSH key, generate one:

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

Press Enter to accept the default location (`~/.ssh/id_rsa`), or specify a custom path.

**Important**: If you set a passphrase, you'll need to use `ssh-agent` or enter it each time.

### Get Your Public Key

```bash
cat ~/.ssh/id_rsa.pub
```

Copy the entire output - you'll need it in Step 4.

---

## Step 3: Generate Password Hash

Generate a password hash for the `kairos` user. You can either:

### Option A: Use OpenSSL (Recommended)

```bash
openssl passwd -1 "your_secure_password"
```

Copy the output (starts with `$1$` or `$6$`).

### Option B: Use Python

```bash
python3 -c "import crypt; print(crypt.crypt('your_secure_password', crypt.mksalt(crypt.METHOD_SHA512)))"
```

**Security Note**: Choose a strong password. The hash will be stored in your configuration.

---

## Step 4: Configure OpenTofu

### 4.1 Navigate to Terraform Directory

```bash
cd terraform
```

### 4.2 Initialize OpenTofu

```bash
tofu init
```

This will download the required providers (k3s, local).

### 4.3 Create Configuration File

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 4.4 Edit Configuration

Open `terraform.tfvars` in your editor and update the following:

#### Network Configuration

Adjust if your network differs:

```hcl
network = {
  subnet      = "192.168.178.0/24"  # Your network subnet
  gateway     = "192.168.178.1"     # Your router/gateway IP
  dns_servers = ["192.168.178.11", "8.8.8.8"]  # Your DNS servers
  interface   = "eth0"              # Network interface name
}
```

#### Node IPs and Hostnames

Verify or change the IP addresses:

```hcl
master_node = {
  hostname = "k3s-master"
  ip       = "192.168.178.15"  # Ensure this IP is free in your network
}

worker_nodes = [
  {
    hostname = "k3s-worker-1"
    ip       = "192.168.178.16"  # Ensure this IP is free
  },
  {
    hostname = "k3s-worker-2"
    ip       = "192.168.178.17"  # Ensure this IP is free
  },
  {
    hostname = "k3s-worker-3"
    ip       = "192.168.178.18"  # Ensure this IP is free
  }
]
```

**Important**: Make sure these IPs are not used by other devices. Consider reserving them in your router's DHCP settings.

#### User Configuration

Update with your SSH key and password hash:

```hcl
user = {
  name              = "kairos"
  password_hash     = "$6$..."  # Paste the hash from Step 3
  ssh_authorized_keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC..."  # Paste your public key from Step 2
  ]
  groups            = ["admin", "sudo", "docker", "wheel"]
  shell             = "/bin/bash"
}
```

#### K3s Configuration (Temporary)

For now, use a placeholder token. We'll update this after the master node is installed:

```hcl
k3s = {
  token              = "PLACEHOLDER_TOKEN_WILL_BE_UPDATED"  # We'll get the real token in Step 7
  flannel_backend    = "host-gw"
  master_node_ip     = "192.168.178.15"
}

k3s_api_endpoint = "https://192.168.178.15:6443"
k3s_token         = "PLACEHOLDER_TOKEN_WILL_BE_UPDATED"  # We'll get the real token in Step 7
```

#### Installation Device

Verify the installation device (usually `/dev/sda` for SATA SSDs):

```hcl
install_device = "/dev/sda"  # Change to /dev/nvme0n1 for NVMe SSDs
```

---

## Step 5: Generate Cloud-Init Files

Generate the cloud-init configuration files:

```bash
tofu plan
```

Review the planned changes. You should see that 4 files will be created:
- `k3s-master.yaml`
- `k3s-worker-1.yaml`
- `k3s-worker-2.yaml`
- `k3s-worker-3.yaml`

Apply the configuration:

```bash
tofu apply
```

Type `yes` when prompted.

The cloud-init files will be generated in `../configs/cloud-init/`.

**Note**: The worker node files will have placeholder tokens. We'll regenerate them after getting the real token.

---

## Step 6: Install Master Node

### 6.1 Prepare USB Stick with Kairos

1. Download Kairos ISO from [Kairos Releases](https://github.com/kairos-io/kairos/releases)
2. Flash the ISO to a USB stick using your preferred tool (e.g., `dd`, Balena Etcher, etc.)

### 6.2 Boot Master Node

1. Insert the USB stick into the first Futro S740 device (this will be the master node)
2. Boot from USB
3. Wait for Kairos to load

### 6.3 Install with Cloud-Init

Copy the master cloud-init file to the USB stick or make it accessible via network, then run:

```bash
kairos-agent install --cloud-init /path/to/k3s-master.yaml
```

Or if the file is on the USB stick:

```bash
# Mount USB stick (adjust device name)
mkdir /mnt/usb
mount /dev/sdb1 /mnt/usb  # Adjust device name as needed
kairos-agent install --cloud-init /mnt/usb/k3s-master.yaml
```

The installation will:
- Install Kairos to the internal storage
- Configure networking
- Set up the user account
- Install and configure K3s master
- Reboot automatically

### 6.4 Wait for Installation

Wait for the installation to complete and the node to reboot. This may take 5-10 minutes.

### 6.5 Verify Master Node

After reboot, verify the master node is accessible:

```bash
ssh kairos@192.168.178.15
```

Check K3s is running:

```bash
sudo systemctl status k3s
```

Check node status:

```bash
sudo k3s kubectl get nodes
```

You should see the master node listed.

---

## Step 7: Retrieve K3s Token from Master

The K3s token is required for worker nodes to join the cluster. Retrieve it from the master node:

### SSH to Master Node

```bash
ssh kairos@192.168.178.15
```

### Get the Token

The token is stored in `/var/lib/rancher/k3s/server/node-token`:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

Copy the entire token (it starts with `K10` and is quite long).

**Example output**:
```
K1091007c87f9b81a426633d1c04f792e3239f59d4c112c6ac8dd015b57b057419e::server:a606a869eca59305ac2a4f596fce0a2f
```

### Exit SSH Session

```bash
exit
```

---

## Step 8: Update Configuration with K3s Token

### 8.1 Update terraform.tfvars

Edit `terraform.tfvars` and replace the placeholder tokens with the real token from Step 7:

```hcl
k3s = {
  token              = "K1091007c87f9b81a426633d1c04f792e3239f59d4c112c6ac8dd015b57b057419e::server:a606a869eca59305ac2a4f596fce0a2f"  # Real token from Step 7
  flannel_backend    = "host-gw"
  master_node_ip     = "192.168.178.15"
}

k3s_api_endpoint = "https://192.168.178.15:6443"
k3s_token         = "K1091007c87f9b81a426633d1c04f792e3239f59d4c112c6ac8dd015b57b057419e::server:a606a869eca59305ac2a4f596fce0a2f"  # Real token from Step 7
```

### 8.2 Regenerate Cloud-Init Files

Regenerate the cloud-init files with the correct token:

```bash
tofu apply
```

Type `yes` when prompted. This will update all worker node configurations with the correct K3s token.

---

## Step 9: Install Worker Nodes

Repeat the installation process for each worker node:

### 9.1 Install Worker Node 1

1. Boot the second Futro S740 from the Kairos USB stick
2. Install using the worker-1 cloud-init file:

```bash
kairos-agent install --cloud-init /path/to/k3s-worker-1.yaml
```

3. Wait for installation and reboot

### 9.2 Install Worker Node 2

1. Boot the third Futro S740 from the Kairos USB stick
2. Install using the worker-2 cloud-init file:

```bash
kairos-agent install --cloud-init /path/to/k3s-worker-2.yaml
```

3. Wait for installation and reboot

### 9.3 Install Worker Node 3

1. Boot the fourth Futro S740 from the Kairos USB stick
2. Install using the worker-3 cloud-init file:

```bash
kairos-agent install --cloud-init /path/to/k3s-worker-3.yaml
```

3. Wait for installation and reboot

### 9.4 Verify Worker Nodes

After all worker nodes have rebooted, verify they're accessible:

```bash
ssh kairos@192.168.178.16  # Worker 1
ssh kairos@192.168.178.17  # Worker 2
ssh kairos@192.168.178.18  # Worker 3
```

---

## Step 10: Verify Cluster

### 10.1 Check Cluster Status from Master

SSH to the master node:

```bash
ssh kairos@192.168.178.15
```

Check all nodes are registered:

```bash
sudo k3s kubectl get nodes
```

You should see all 4 nodes (1 master + 3 workers) in `Ready` state:

```
NAME           STATUS   ROLES                  AGE   VERSION
k3s-master     Ready    control-plane,master   10m   v1.x.x+k3s1
k3s-worker-1   Ready    <none>                 8m   v1.x.x+k3s1
k3s-worker-2   Ready    <none>                 6m   v1.x.x+k3s1
k3s-worker-3   Ready    <none>                 4m   v1.x.x+k3s1
```

### 10.2 Check Pods

Verify system pods are running:

```bash
sudo k3s kubectl get pods -A
```

You should see pods in `kube-system` namespace running.

### 10.3 Test Cluster Connectivity

From your local machine, you can test cluster connectivity (if kubectl is installed):

```bash
# Copy kubeconfig from master
scp kairos@192.168.178.15:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Edit kubeconfig to replace localhost with master IP
sed -i 's/127.0.0.1/192.168.178.15/g' ~/.kube/config

# Test cluster access
kubectl get nodes
```

---

## Step 11: Configure K3s Resource Management

Now that the cluster is running, you can use OpenTofu to manage K3s resources.

### 11.1 Verify K3s Provider Connection

Test that OpenTofu can connect to the cluster:

```bash
cd terraform
tofu plan
```

If there are no errors, the provider is configured correctly.

### 11.2 Add K3s Resources

Edit `modules/k3s/main.tf` or `modules/k3s/resources.tf` to add cluster resources.

Example: Create a namespace

```hcl
resource "k3s_namespace" "example" {
  metadata {
    name = "example"
  }
}
```

### 11.3 Apply K3s Resources

```bash
tofu apply
```

This will create the resources in your K3s cluster.

---

## Troubleshooting

### Master Node Not Accessible

- Verify network cable is connected
- Check IP address is correct: `ip addr show eth0`
- Verify SSH service is running: `sudo systemctl status sshd`
- Check firewall rules

### Worker Nodes Not Joining Cluster

- Verify K3s token is correct in worker cloud-init files
- Check master node IP is reachable from workers: `ping 192.168.178.15`
- Verify K3s service is running on master: `sudo systemctl status k3s`
- Check worker logs: `sudo journalctl -u k3s-agent -f`
- View K3s agent logs on worker nodes:
  ```bash
  sudo tail -n 100 /var/log/k3s-agent.log
  ```
- Follow agent logs in real-time:
  ```bash
  sudo tail -f /var/log/k3s-agent.log
  ```

### K3s Provider Connection Issues

- Verify master node is accessible: `ping 192.168.178.15`
- Check API endpoint is correct: `curl -k https://192.168.178.15:6443`
- Verify token is correct (use the token from `/var/lib/rancher/k3s/server/node-token`)
- Check network connectivity
- View K3s server logs on master node:
  ```bash
  sudo tail -n 100 /var/log/k3s.log
  ```
- Follow server logs in real-time:
  ```bash
  sudo tail -f /var/log/k3s.log
  ```

### Cloud-Init Files Not Generated

- Verify `output_dir` variable is correct
- Check write permissions: `ls -ld ../configs/cloud-init`
- Review OpenTofu logs for errors

### Installation Device Not Found

- Check available devices: `lsblk` or `fdisk -l`
- Update `install_device` in `terraform.tfvars`
- For NVMe SSDs, use `/dev/nvme0n1` instead of `/dev/sda`

### K3s Logs and Debugging

#### View K3s Server Logs (Master Node)

On the master node, view the last 100 lines of K3s server logs:

```bash
sudo tail -n 100 /var/log/k3s.log
```

Follow server logs in real-time:

```bash
sudo tail -f /var/log/k3s.log
```

View all server logs:

```bash
sudo cat /var/log/k3s.log
```

#### View K3s Agent Logs (Worker Nodes)

On worker nodes, view the last 100 lines of K3s agent logs:

```bash
sudo tail -n 100 /var/log/k3s-agent.log
```

Follow agent logs in real-time:

```bash
sudo tail -f /var/log/k3s-agent.log
```

View all agent logs:

```bash
sudo cat /var/log/k3s-agent.log
```

#### Alternative: Using journalctl

You can also use `journalctl` to view logs:

**Master node (server):**
```bash
sudo journalctl -u k3s -n 100
sudo journalctl -u k3s -f
```

**Worker nodes (agent):**
```bash
sudo journalctl -u k3s-agent -n 100
sudo journalctl -u k3s-agent -f
```

#### Common Log Locations

- **Server logs**: `/var/log/k3s.log`
- **Agent logs**: `/var/log/k3s-agent.log`
- **Systemd service logs**: Use `journalctl -u k3s` or `journalctl -u k3s-agent`

#### Debugging Tips

1. **Check for connection errors**: Look for "connection refused" or "timeout" messages
2. **Verify token format**: Token should start with `K10` and be quite long
3. **Check network connectivity**: Ensure master IP is reachable from workers
4. **Verify service status**: `sudo systemctl status k3s` (master) or `sudo systemctl status k3s-agent` (workers)
5. **Check certificate issues**: Look for SSL/TLS errors in logs

---

## Next Steps

- Set up persistent storage (e.g., NFS, Longhorn)
- Configure ingress controller (e.g., Traefik, Nginx)
- Deploy applications to the cluster
- Set up monitoring and logging
- Configure backup strategies

---

## References

- [OpenTofu Documentation](https://opentofu.org/docs)
- [K3s Provider Documentation](https://registry.terraform.io/providers/k3s-io/k3s/latest/docs)
- [Kairos Documentation](https://kairos.io/docs/)
- [K3s Documentation](https://docs.k3s.io/)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)

---

## Security Notes

- **Never commit `terraform.tfvars`** - it contains sensitive data (tokens, password hashes)
- **Use strong passwords** for the kairos user
- **Keep SSH keys secure** - don't share private keys
- **Rotate K3s tokens** periodically in production environments
- **Consider firewall rules** to restrict access to the cluster
- **Update regularly** - keep Kairos, K3s, and OpenTofu up to date

