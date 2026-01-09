# Self-Signed Certificate Setup for Local Domain

This directory contains the self-signed TLS certificate and key for the local domain (e.g., `homelab.local`).

## Prerequisites

- OpenSSL installed on your system
- Access to the Terraform directory

## Step 1: Create Certificate Directory

Create the `certs` directory in the Terraform root if it doesn't exist:

```bash
mkdir -p terraform/certs
cd terraform/certs
```

## Step 2: Generate Self-Signed Certificate

Generate a wildcard certificate for your local domain (e.g., `*.homelab.local`):

```bash
# Replace <your-domain> with your actual domain (e.g., homelab.local)
DOMAIN="<your-domain>"

# Generate private key
openssl genrsa -out ${DOMAIN}.key 2048

# Generate certificate signing request
openssl req -new -key ${DOMAIN}.key -out ${DOMAIN}.csr \
  -subj "/C=DE/ST=State/L=City/O=Organization/CN=*.${DOMAIN}"

# Generate self-signed certificate (valid for 10 years)
openssl x509 -req -days 3650 -in ${DOMAIN}.csr \
  -signkey ${DOMAIN}.key -out ${DOMAIN}.crt \
  -extensions v3_req -extfile <(
    echo "[v3_req]"
    echo "keyUsage = keyEncipherment, dataEncipherment"
    echo "extendedKeyUsage = serverAuth"
    echo "subjectAltName = @alt_names"
    echo "[alt_names]"
    echo "DNS.1 = *.${DOMAIN}"
    echo "DNS.2 = ${DOMAIN}"
  )

# Clean up CSR file (optional)
rm ${DOMAIN}.csr
```

**Important:** Replace `<your-domain>` with your actual local domain name (e.g., `homelab.local`).

## Step 3: Verify Certificate

Verify the certificate was created correctly:

```bash
# Replace <your-domain> with your actual domain
openssl x509 -in <your-domain>.crt -text -noout

# Verify the certificate includes the wildcard domain
openssl x509 -in <your-domain>.crt -text -noout | grep -A 2 "Subject Alternative Name"
```

You should see `DNS:*.<your-domain>` and `DNS:<your-domain>` in the output.

## Step 4: Set Proper Permissions

Set secure permissions on the certificate files:

```bash
# Replace <your-domain> with your actual domain
chmod 600 <your-domain>.key
chmod 644 <your-domain>.crt
```

## Step 5: Apply Terraform Configuration

After creating the certificate files, apply your Terraform configuration:

```bash
cd terraform
terraform apply
```

Terraform will automatically:
1. Create a Kubernetes Secret `traefik-local-tls` in the `kube-system` namespace
2. Configure Traefik to use this certificate via the default TLS Store
3. Create Ingress resources for all services with the local domain

## Step 6: Trust the Certificate (Client-Side)

To avoid browser warnings, you need to trust the self-signed certificate on your client machines:

### macOS

```bash
# Replace <your-domain> with your actual domain
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain <your-domain>.crt
```

### Linux

```bash
# Replace <your-domain> with your actual domain
sudo cp <your-domain>.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### Windows

1. Double-click the `<your-domain>.crt` file
2. Click "Install Certificate"
3. Select "Local Machine" → "Place all certificates in the following store"
4. Browse to "Trusted Root Certification Authorities"
5. Click "Next" → "Finish"

### Browser-Specific

**Chrome/Edge:**
- Settings → Privacy and security → Security → Manage certificates
- Import the certificate to "Trusted Root Certification Authorities"

**Firefox:**
- Settings → Privacy & Security → Certificates → View Certificates → Authorities → Import

## DNS Configuration

**IMPORTANT:** The Terraform configuration does NOT automatically create DNS records for the local domain. You must configure DNS resolution manually.

### Option 1: Configure DNS Server (Recommended for Network-Wide Access)

Configure your DNS server to resolve `*.<your-domain>` to your master node IP.

**For Technitium DNS Server:**

1. **Log into Technitium DNS Server web interface** (usually `http://<dns-server-ip>:5380`)

2. **Create the zone:**
   - Go to **DNS Zones** → **Add Zone**
   - Zone Name: `<your-domain>` (e.g., `homelab.local`)
   - Zone Type: **Primary** (not Secondary or Stub)
   - Click **Add Zone**

3. **Add wildcard A record:**
   - Open the `<your-domain>` zone
   - Click **Add Record**
   - Record Type: **A**
   - **Name/Record**: `*` (just an asterisk, no quotes, no domain suffix)
   - **IP Address**: `<master-node-ip>`
   - **TTL**: 300 (or leave default)
   - Click **Add Record**

4. **Verify zone is active:**
   - Make sure the zone status shows as **Active** or **Enabled**
   - If zone is disabled, enable it

5. **Important notes for Technitium:**
   - The wildcard record name should be just `*` (not `*.<your-domain>`)
   - The zone must be of type **Primary**
   - After adding records, the zone should automatically be active
   - No need to "apply" - changes take effect immediately

6. **Troubleshooting:**
   - If it still doesn't work, try adding individual A records for each service:
     - `<service-name>` → `<master-node-ip>`
     - Repeat for each service you want to access
   - Clear DNS cache on your client: `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` (macOS) or `sudo systemd-resolve --flush-caches` (Linux)
   - If available, run the debug script: `./terraform/debug-dns-server.sh`

**For other DNS servers:**
- Create a wildcard A record: `*.<your-domain>` → `<master-node-ip>`
- Or create individual A records for each service (e.g., `<service-name>.<your-domain>`)

**Verify DNS configuration:**
```bash
# Replace <your-domain> and <dns-server-ip> with your actual values
# Should resolve to master node IP
nslookup <service-name>.<your-domain> <dns-server-ip>

# Or use dig for more detailed output
dig @<dns-server-ip> <service-name>.<your-domain> A
dig @<dns-server-ip> <your-domain> SOA  # Should show zone exists

# If available, run comprehensive DNS debug script
cd terraform
./debug-dns-server.sh
```

### Option 2: Use /etc/hosts (Quick Fix for Single Machine)

If DNS server configuration is not possible, add entries to `/etc/hosts` on your client machine:

**macOS/Linux:**
```bash
# Get master node IP (if kubectl is available)
MASTER_IP=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/control-plane=="")].status.addresses[?(@.type=="InternalIP")].address}')

# Or set manually: MASTER_IP="<master-node-ip>"

# Add to /etc/hosts (requires sudo)
# Replace <service-name> and <your-domain> with your actual values
echo "$MASTER_IP <service-name-1>.<your-domain> <service-name-2>.<your-domain> <service-name-3>.<your-domain>" | sudo tee -a /etc/hosts
```

**Windows:**
1. Open Notepad as Administrator
2. Open `C:\Windows\System32\drivers\etc\hosts`
3. Add line: `<master-node-ip> <service-name-1>.<your-domain> <service-name-2>.<your-domain> <service-name-3>.<your-domain>`
4. Save and close

**Note:** `/etc/hosts` only works on the machine where it's configured. For network-wide access, use Option 1.

## Troubleshooting

### Certificate Not Found Error

If Terraform reports that the certificate files are missing:
- Ensure the files are named exactly `<your-domain>.crt` and `<your-domain>.key` (e.g., `homelab.local.crt` and `homelab.local.key`)
- Check that the files are in the `terraform/certs/` directory
- Verify file permissions allow reading

### Certificate Expired

The certificate is valid for 10 years (3650 days). To renew:
1. Follow Step 2 again to generate a new certificate
2. Apply Terraform configuration again

### Services Not Accessible via Local Domain

1. **Check DNS resolution:**
   ```bash
   # Replace <service-name> and <your-domain> with your actual values
   nslookup <service-name>.<your-domain>
   ```
   If it returns NXDOMAIN, DNS is not configured. See "DNS Configuration" section above.

2. **Check Kubernetes Ingress resources:**
   ```bash
   # Replace <your-domain> with your actual domain
   kubectl get ingress -A | grep <your-domain>
   ```
   Should show ingress resources for local domain.

3. **Check Traefik logs:**
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
   ```

4. **Verify the TLS Secret exists:**
   ```bash
   kubectl get secret traefik-local-tls -n kube-system
   ```

5. **Check TLS Store:**
   ```bash
   kubectl get tlsstore default -n kube-system
   ```

6. **Run debug script (if available):**
   ```bash
   ./terraform/debug-dns.sh
   ```

## File Structure

After setup, your `terraform/certs/` directory should contain:

```
terraform/certs/
├── README.md (this file)
├── <your-domain>.crt (certificate, e.g., homelab.local.crt)
└── <your-domain>.key (private key - keep secure!, e.g., homelab.local.key)
```

**Security Note:** Never commit the private key (`*.key`) to version control. Add it to `.gitignore`:

```gitignore
# In terraform/.gitignore
certs/*.key
certs/*.csr
```

## Additional Notes

- The certificate uses a wildcard (`*.<your-domain>`) to cover all subdomains
- Services will be accessible at `<service-name>.<your-domain>`
- The certificate is automatically used by Traefik for all Ingress resources configured with the local domain
- External services (from `external_services` variable) will be accessible at `<service-name>.<your-domain>`
- Internal services will be accessible at their respective subdomains (e.g., `<service-name>.<your-domain>`)

