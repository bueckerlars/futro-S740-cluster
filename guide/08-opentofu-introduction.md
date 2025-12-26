# Kapitel 8: OpenTofu Einführung

## Übersicht

In diesem Kapitel lernst du OpenTofu kennen, ein Tool für Infrastructure as Code (IaC). Du wirst verstehen, wie du deine Infrastruktur versionierst und automatisiert verwaltest.

## Was ist OpenTofu?

OpenTofu ist ein Open-Source-Fork von Terraform, entwickelt von der Linux Foundation. Es ermöglicht dir, Infrastruktur als Code zu definieren.

### Infrastructure as Code (IaC)

**Was bedeutet das?**
- Infrastruktur wird in Code-Dateien definiert (nicht manuell konfiguriert)
- Versionierung mit Git
- Reproduzierbar und dokumentiert
- Automatische Anwendung von Änderungen

**Vorteile**:
- **Konsistenz**: Gleiche Infrastruktur jedes Mal
- **Versionierung**: Änderungen nachvollziehbar
- **Kollaboration**: Team kann zusammenarbeiten
- **Dokumentation**: Code ist die Dokumentation

### OpenTofu vs. Terraform

OpenTofu ist ein Fork von Terraform:
- **Kompatibel**: Verwendet gleiche Syntax und Konzepte
- **Open Source**: Keine kommerziellen Beschränkungen
- **Community-driven**: Entwickelt von der Community

**Für unseren Use-Case**: Beide sind ähnlich, OpenTofu ist vollständig Open Source.

## Installation

### Linux

```bash
# Download von opentofu.org
wget https://github.com/opentofu/opentofu/releases/latest/download/tofu_linux_amd64.zip
unzip tofu_linux_amd64.zip
sudo mv tofu /usr/local/bin/
```

### Mac

```bash
brew install opentofu/tap/tofu
```

### Windows

```bash
choco install opentofu
```

### Verifikation

```bash
tofu version
# Sollte Version anzeigen
```

## Grundlegende Konzepte

### Provider

Ein Provider ist ein Plugin, das mit einer bestimmten Infrastruktur-Plattform kommuniziert.

**Beispiele**:
- `local`: Lokale Dateien und Befehle
- `null`: Dummy-Provider für Tests
- `random`: Zufällige Werte generieren
- `dns`: DNS-Einträge verwalten (falls du DNS hast)

### Resources

Resources sind die Bausteine deiner Infrastruktur.

**Beispiel**:
```hcl
resource "local_file" "config" {
  filename = "/tmp/config.txt"
  content  = "Hello, World!"
}
```

### State

OpenTofu speichert den aktuellen Zustand deiner Infrastruktur in einer State-Datei.

**Wichtig**:
- State zeigt, was aktuell existiert
- Wird verwendet, um Änderungen zu planen
- Sollte versioniert werden (mit Vorsicht!)

### Plan und Apply

1. **Plan**: Zeigt, was geändert wird (ohne Änderungen)
2. **Apply**: Wendet Änderungen an

## Erste Schritte

### Projekt-Struktur

```bash
# Erstelle Verzeichnis für OpenTofu
mkdir -p ~/cluster-iac/opentofu
cd ~/cluster-iac/opentofu
```

### Beispiel: Einfache Datei erstellen

Erstelle `main.tf`:

```hcl
# main.tf
terraform {
  required_version = ">= 1.0"
  
  # Optional: Remote State (später)
  # backend "local" {}
}

# Provider konfigurieren
provider "local" {
  # Keine Konfiguration nötig für local provider
}

# Resource: Lokale Datei
resource "local_file" "cluster_config" {
  filename = "${path.module}/cluster-config.txt"
  content  = <<-EOT
    Cluster: futro-cluster
    Master: 10.10.10.10
    Workers: 10.10.10.11-13
  EOT
}
```

### OpenTofu initialisieren

```bash
# Provider herunterladen
tofu init

# Sollte zeigen:
# Terraform has been successfully initialized!
```

### Plan ausführen

```bash
# Zeigt, was erstellt wird (ohne Änderungen)
tofu plan

# Sollte zeigen:
# local_file.cluster_config will be created
```

### Apply ausführen

```bash
# Änderungen anwenden
tofu apply

# Bestätige mit "yes"
# Datei wird erstellt
```

### Verifikation

```bash
# Datei sollte existieren
cat cluster-config.txt

# State anzeigen
tofu show
```

## Praktische Beispiele für deinen Cluster

### Beispiel 1: IP-Adress-Dokumentation

```hcl
# ip-management.tf
variable "cluster_name" {
  description = "Name des Clusters"
  type        = string
  default     = "futro-cluster"
}

variable "vlan_subnet" {
  description = "VLAN Subnetz"
  type        = string
  default     = "10.10.10.0/24"
}

# Master Node
resource "local_file" "master_config" {
  filename = "${path.module}/nodes/master.txt"
  content  = <<-EOT
    Hostname: k3s-master
    IP: 10.10.10.10
    Role: control-plane
  EOT
}

# Worker Nodes
resource "local_file" "worker_configs" {
  for_each = {
    "worker-1" = "10.10.10.11"
    "worker-2" = "10.10.10.12"
    "worker-3" = "10.10.10.13"
  }
  
  filename = "${path.module}/nodes/${each.key}.txt"
  content  = <<-EOT
    Hostname: k3s-${each.key}
    IP: ${each.value}
    Role: worker
  EOT
}
```

### Beispiel 2: DNS-Einträge (falls DNS vorhanden)

```hcl
# dns.tf (Beispiel - benötigt DNS Provider)
provider "dns" {
  # Konfiguration je nach DNS-Server
}

resource "dns_a_record_set" "master" {
  zone = "cluster.local."
  name = "k3s-master"
  addresses = ["10.10.10.10"]
  ttl = 300
}

resource "dns_a_record_set" "workers" {
  for_each = {
    "worker-1" = "10.10.10.11"
    "worker-2" = "10.10.10.12"
    "worker-3" = "10.10.10.13"
  }
  
  zone      = "cluster.local."
  name      = "k3s-${each.key}"
  addresses = [each.value]
  ttl       = 300
}
```

### Beispiel 3: Konfigurations-Templates

```hcl
# templates.tf
variable "nfs_server" {
  description = "NFS Server IP"
  type        = string
  default     = "10.10.10.20"
}

variable "nfs_path" {
  description = "NFS Export Path"
  type        = string
  default     = "/mnt/storage/k3s"
}

# Template für NFS-Konfiguration
resource "local_file" "nfs_config" {
  filename = "${path.module}/nfs-config.yaml"
  content = templatefile("${path.module}/templates/nfs-config.tpl", {
    nfs_server = var.nfs_server
    nfs_path   = var.nfs_path
  })
}
```

Erstelle `templates/nfs-config.tpl`:

```yaml
# NFS Storage Configuration
nfs:
  server: ${nfs_server}
  path: ${nfs_path}
  version: "4"
```

## Variablen und Outputs

### Variablen definieren

```hcl
# variables.tf
variable "cluster_name" {
  description = "Name des Clusters"
  type        = string
  default     = "futro-cluster"
}

variable "node_ips" {
  description = "IP-Adressen der Nodes"
  type        = map(string)
  default = {
    master   = "10.10.10.10"
    worker-1 = "10.10.10.11"
    worker-2 = "10.10.10.12"
    worker-3 = "10.10.10.13"
  }
}
```

### Variablen verwenden

```hcl
# main.tf
resource "local_file" "cluster_info" {
  filename = "${path.module}/cluster-info.txt"
  content  = "Cluster: ${var.cluster_name}\nMaster: ${var.node_ips["master"]}"
}
```

### Outputs definieren

```hcl
# outputs.tf
output "master_ip" {
  description = "Master Node IP"
  value       = var.node_ips["master"]
}

output "worker_ips" {
  description = "Worker Node IPs"
  value       = var.node_ips
}
```

### Outputs anzeigen

```bash
# Nach apply
tofu output

# Spezifischer Output
tofu output master_ip
```

## State Management

### Lokaler State

Standardmäßig wird State in `terraform.tfstate` gespeichert.

**Wichtig**:
- State enthält sensible Daten
- Sollte nicht öffentlich versioniert werden
- Backup regelmäßig erstellen

### State anzeigen

```bash
# Aktuellen State anzeigen
tofu show

# State-Liste
tofu state list

# Spezifische Resource
tofu state show local_file.cluster_config
```

### State sichern

```bash
# State-Datei sichern
cp terraform.tfstate terraform.tfstate.backup

# Oder in Git (mit .gitignore für sensible Daten)
```

### .gitignore

Erstelle `.gitignore`:

```
# OpenTofu
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
crash.log
*.tfvars
!terraform.tfvars.example
```

## Workflow

### Typischer Workflow

1. **Code schreiben**: `.tf` Dateien erstellen/bearbeiten
2. **Formatieren**: `tofu fmt` (Code formatieren)
3. **Validieren**: `tofu validate` (Syntax prüfen)
4. **Planen**: `tofu plan` (Änderungen anzeigen)
5. **Anwenden**: `tofu apply` (Änderungen anwenden)

### Befehle im Detail

```bash
# Code formatieren
tofu fmt

# Syntax validieren
tofu validate

# Plan erstellen
tofu plan

# Plan in Datei speichern
tofu plan -out=tfplan

# Plan anwenden
tofu apply tfplan

# Änderungen anwenden (interaktiv)
tofu apply

# Ressource zerstören
tofu destroy
```

## Best Practices

### 1. Modulare Struktur

```bash
opentofu/
├── main.tf
├── variables.tf
├── outputs.tf
├── modules/
│   └── network/
│       ├── main.tf
│       └── variables.tf
└── environments/
    ├── dev/
    └── prod/
```

### 2. Variablen verwenden

- Keine Hardcoded-Werte
- Sensible Daten in `*.tfvars` (nicht versionieren!)
- Defaults für einfache Nutzung

### 3. Dokumentation

```hcl
# Gute Dokumentation
variable "cluster_name" {
  description = "Name des Kubernetes-Clusters"
  type        = string
  default     = "futro-cluster"
  
  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "Cluster-Name darf nicht leer sein."
  }
}
```

### 4. State Management

- State regelmäßig sichern
- Sensible Daten nicht versionieren
- Remote State für Team (später)

## Für deinen Cluster

### Was kannst du mit OpenTofu machen?

1. **IP-Management**: Dokumentation und Verwaltung
2. **DNS-Einträge**: Automatische DNS-Konfiguration (falls DNS vorhanden)
3. **Konfigurations-Templates**: Generiere Config-Files
4. **Dokumentation**: Automatische Generierung von Dokumentation

### Was OpenTofu NICHT macht

- **K3S Installation**: Dafür verwenden wir Ansible (siehe [Kapitel 9](09-ansible-introduction.md))
- **Kubernetes-Ressourcen**: Dafür verwenden wir kubectl/Helm
- **System-Konfiguration**: Dafür verwenden wir Ansible

## Übungen

### Übung 1: Basis-Setup

1. Erstelle ein OpenTofu-Projekt
2. Definiere Variablen für deine Cluster-IPs
3. Erstelle Dateien mit Node-Konfiguration
4. Führe `tofu apply` aus

### Übung 2: Templates

1. Erstelle ein Template für NFS-Konfiguration
2. Verwende Variablen für NFS-Server und -Path
3. Generiere die Config-Datei

## Checkliste

Du solltest jetzt verstehen:
- [ ] Was OpenTofu ist und wofür es verwendet wird
- [ ] Grundlegende Konzepte (Provider, Resources, State)
- [ ] Wie du ein OpenTofu-Projekt erstellst
- [ ] Wie du Variablen und Outputs verwendest
- [ ] Den typischen Workflow (init, plan, apply)

## Nächste Schritte

Jetzt, da du OpenTofu kennst, geht es weiter mit [Kapitel 9: Ansible Einführung](09-ansible-introduction.md), wo du lernst, wie du System-Konfiguration und K3S-Installation automatisiert.

## Weiterführende Ressourcen

- [OpenTofu Dokumentation](https://opentofu.org/docs)
- [OpenTofu Provider Registry](https://registry.opentofu.org/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html) (gilt auch für OpenTofu)
- [OpenTofu GitHub](https://github.com/opentofu/opentofu)

