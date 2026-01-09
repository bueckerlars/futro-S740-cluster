# Monitoring Module

This module deploys a complete monitoring stack for the Kubernetes cluster using Prometheus and Grafana. It is based on the [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) Helm chart, which includes Prometheus Operator, Prometheus, Grafana, and Alertmanager.

## Overview

The monitoring module provides:

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Prometheus Operator**: Kubernetes-native Prometheus management
- **cAdvisor Integration**: Container and node metrics via Kubernetes API proxy
- **Pre-configured Dashboard**: Kubernetes Cluster Monitoring Dashboard (ID: 315)

## Components

### Prometheus

- **Service Type**: ClusterIP
- **Access**: Via Ingress on local domain (e.g., `prometheus.homelab.local`)
- **Retention**: 15 days
- **Scrape Config**: Configured for cAdvisor metrics via Kubernetes API proxy

### Grafana

- **Service Type**: ClusterIP
- **Access**: Via Ingress on external domain (e.g., `grafana.example.com`) and local domain (e.g., `grafana.homelab.local`)
- **Default Username**: `admin`
- **Default Password**: `admin` (configurable)
- **Dashboard Auto-Import**: Attempts to automatically import Dashboard 315

### Prometheus Operator

- Manages Prometheus and ServiceMonitor CRDs
- Enables Kubernetes-native monitoring configuration

## Prerequisites

- Kubernetes cluster must be running and accessible
- Helm provider configured with access to the cluster
- Kubernetes provider configured with valid kubeconfig
- Traefik Ingress Controller configured and running
- DNS records configured for external domain (if using external domain)
- DNS records configured for local domain (if using local domain)

## Usage

### Basic Usage

```hcl
module "monitoring" {
  source = "./modules/services/monitoring"

  domain                 = "<your-domain>"
  local_domain            = "<your-local-domain>"  # Optional, e.g., "homelab.local"
  grafana_admin_password = "secure-password"

  depends_on = [
    null_resource.kubeconfig,
    time_sleep.wait_for_cluster
  ]
}
```

### With Custom Namespace

```hcl
module "monitoring" {
  source = "./modules/services/monitoring"

  namespace              = "custom-monitoring"
  domain                 = "<your-domain>"
  local_domain            = "<your-local-domain>"
  grafana_admin_password = var.grafana_password
}
```

## Input Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `namespace` | `string` | `"monitoring"` | Namespace for monitoring resources |
| `domain` | `string` | *required* | External domain name for Grafana Ingress (e.g., `example.com`) |
| `local_domain` | `string` | `""` | Local domain name for Ingress (e.g., `homelab.local`). Used for local network access with self-signed certificates |
| `grafana_admin_password` | `string` | `"admin"` | Admin password for Grafana (sensitive) |

## Outputs

| Output | Description |
|--------|-------------|
| `prometheus_urls` | URLs to access Prometheus UI (all domains, e.g., `{ local = "https://prometheus.homelab.local" }`) |
| `grafana_urls` | URLs to access Grafana UI (all domains, e.g., `{ external = "https://grafana.example.com", local = "https://grafana.homelab.local" }`) |
| `grafana_admin_password` | Admin password for Grafana (sensitive) |
| `namespace` | Namespace where monitoring resources are deployed |

## Accessing Services

After deployment, access the services via Ingress:

- **Prometheus**: `https://prometheus.<local-domain>` (e.g., `https://prometheus.homelab.local`)
- **Grafana (External)**: `https://grafana.<domain>` (e.g., `https://grafana.example.com`)
- **Grafana (Local)**: `https://grafana.<local-domain>` (e.g., `https://grafana.homelab.local`)

**Note**: Prometheus is only accessible via the local domain. Grafana is accessible via both external and local domains.

### Grafana Login

- **Username**: `admin`
- **Password**: Value from `grafana_admin_password` variable (default: `admin`)

You can retrieve the password from Terraform outputs:

```bash
tofu output -module monitoring grafana_admin_password
```

### TLS Certificates

- **External Domain**: Uses Let's Encrypt certificates (automatically managed by Traefik)
- **Local Domain**: Uses self-signed certificates (configured via TLS Store in `kube-system` namespace)

## Dashboard

### Kubernetes Cluster Monitoring Dashboard (ID: 315)

The module attempts to automatically import the [Kubernetes Cluster Monitoring Dashboard](https://grafana.com/grafana/dashboards/315-kubernetes-cluster-monitoring-via-prometheus/) via the Grafana API.

**Features:**
- Total and used cluster resources: CPU, memory, filesystem
- Cluster network I/O pressure
- Kubernetes pods usage: CPU, memory, network I/O
- Containers usage: CPU, memory, network I/O
- systemd system services usage: CPU, memory
- Metrics for all cluster and each node separately

**Manual Import (if auto-import fails):**

1. Log in to Grafana
2. Navigate to **Dashboards** → **Import**
3. Enter Dashboard ID: `315`
4. Select Prometheus as data source
5. Click **Import**

## Prometheus Configuration

### cAdvisor Metrics

The module configures Prometheus to scrape cAdvisor metrics via the Kubernetes API proxy. This configuration:

- Uses Kubernetes service discovery to find all nodes
- Scrapes metrics from `/api/v1/nodes/{node}/proxy/metrics/cadvisor`
- Scrape interval: 10 seconds
- Includes relabeling for rkt and systemd containers

### Service Monitors

The Prometheus Operator is configured to discover ServiceMonitors across all namespaces (`serviceMonitorSelectorNilUsesHelmValues: false`). This allows you to create ServiceMonitor resources in any namespace to automatically scrape metrics from your applications.

## Troubleshooting

### Services Not Accessible

1. **Check if services are running:**
   ```bash
   kubectl get pods -n monitoring
   ```

2. **Check service endpoints:**
   ```bash
   kubectl get svc -n monitoring
   ```

3. **Verify Ingress resources:**
   ```bash
   kubectl get ingress -n monitoring
   ```

4. **Check Ingress details:**
   ```bash
   kubectl describe ingress -n monitoring grafana
   kubectl describe ingress -n monitoring prometheus-local
   ```

5. **Verify DNS resolution:**
   ```bash
   nslookup grafana.<your-domain>
   nslookup prometheus.<your-local-domain>
   ```

### Prometheus Not Scraping Metrics

1. **Check Prometheus targets:**
   - Access Prometheus UI: `https://prometheus.<your-local-domain>`
   - Navigate to **Status** → **Targets**
   - Verify `kubernetes-nodes-cadvisor` job is present and healthy

2. **Check Prometheus logs:**
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
   ```

3. **Verify RBAC permissions:**
   ```bash
   kubectl get clusterrolebinding | grep prometheus
   ```

### Grafana Dashboard Not Imported

If the automatic dashboard import fails:

1. **Check import logs:**
   - The `null_resource.import_grafana_dashboard` will output error messages
   - Check Terraform apply output for import status

2. **Manual import:**
   - Follow the manual import steps in the Dashboard section above

3. **Verify Grafana API access:**
   ```bash
   # Via external domain
   curl -k -u admin:<password> https://grafana.<your-domain>/api/health
   
   # Via local domain
   curl -k -u admin:<password> https://grafana.<your-local-domain>/api/health
   ```

### Filesystem Usage Shows N/A

If filesystem usage panels display `N/A` in the dashboard:

- The dashboard filter `device=~"^/dev/[vs]da9$"` may not match your system's devices
- Check actual device names: `lsblk` or `df -h` on cluster nodes
- Update the dashboard query to match your device naming pattern

### High Resource Usage

If Prometheus or Grafana consume too many resources:

1. **Adjust retention period:**
   - Edit `prometheus.prometheusSpec.retention` in `main.tf` (default: 15d)

2. **Scale down scrape interval:**
   - Edit `scrape_interval` in cAdvisor config (default: 10s)

3. **Limit metrics collection:**
   - Configure metric relabeling to drop unnecessary metrics

## Storage

The module uses the default StorageClass for persistent volumes. Ensure your cluster has a default StorageClass configured (e.g., via the NFS provisioner module).

## Security Considerations

- **Ingress Access**: Services are accessible via Ingress only. No direct NodePort exposure.
- **TLS Encryption**: All services use HTTPS (Let's Encrypt for external domain, self-signed for local domain).
- **Default Password**: Change the default Grafana admin password in production.
- **Network Access**: Ensure DNS records point to your cluster and network security policies are in place.
- **RBAC**: Prometheus Operator creates necessary RBAC resources automatically.
- **Local Domain**: Self-signed certificates require client-side trust configuration (see certs/README.md).

## Upgrading

To upgrade the Helm chart version:

1. Update the `version` in `main.tf`:
   ```hcl
   chart      = "kube-prometheus-stack"
   version    = "58.0.0"  # Update to desired version
   ```

2. Review [Helm chart changelog](https://github.com/prometheus-community/helm-charts/releases) for breaking changes

3. Apply changes:
   ```bash
   tofu plan
   tofu apply
   ```

## References

- [kube-prometheus-stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Kubernetes Cluster Monitoring Dashboard](https://grafana.com/grafana/dashboards/315-kubernetes-cluster-monitoring-via-prometheus/)
- [Prometheus Operator Documentation](https://github.com/prometheus-operator/prometheus-operator)
- [Grafana Documentation](https://grafana.com/docs/)
- [cAdvisor Documentation](https://github.com/google/cadvisor)

## Module Dependencies

This module depends on:

- `kubernetes` provider (configured in root module)
- `helm` provider (configured in root module)
- `time` provider (for wait resources)
- `null` provider (for dashboard import)

Ensure these providers are properly configured in the root module before using this module.

