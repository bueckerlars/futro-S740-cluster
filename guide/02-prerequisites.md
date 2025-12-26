# Kapitel 2: Voraussetzungen

## Übersicht

In diesem Kapitel überprüfst du alle Hardware- und Software-Voraussetzungen, planst dein Netzwerk und bereitest alles für die Installation vor.

## Hardware-Checkliste

### Fujitsu Futro S740

Du benötigst **4x Fujitsu Futro S740** Geräte. Überprüfe folgendes:

- [ ] Alle 4 Geräte sind physisch vorhanden
- [ ] Netzwerk-Anschlüsse funktionieren
- [ ] Boot-Medium (USB-Stick) ist vorbereitet
- [ ] Monitor/Tastatur für initiale Installation verfügbar (oder IP-KVM)
- [ ] Seriennummern notiert (für Dokumentation)

**Technische Spezifikationen (typisch)**:
- CPU: AMD GX-412TC oder ähnlich
- RAM: 4-8GB (ausreichend für K3S)
- Storage: 16-32GB eMMC oder SSD
- Netzwerk: 1x Gbit Ethernet

### Netzwerk-Equipment

- [ ] **Managed 8 Port Gbit Switch** ist vorhanden
- [ ] Switch unterstützt VLANs
- [ ] Zugriff auf Switch-Web-Interface oder CLI
- [ ] Dokumentation des Switches verfügbar

### Storage

- [ ] **NFS-Server** ist vorhanden und erreichbar
- [ ] NFS-Export ist konfiguriert (oder wird konfiguriert)
- [ ] NFS-Version bekannt (v3 oder v4)
- [ ] Zugriffsrechte verstanden

### Management-Workstation

Du benötigst einen Computer, von dem aus du den Cluster verwaltest:

- [ ] Linux/Mac/Windows mit SSH-Client
- [ ] Terminal/Command-Line-Zugriff
- [ ] Internet-Zugang für Downloads
- [ ] Genug Speicherplatz für Tools (kubectl, OpenTofu, Ansible, Helm)

## Netzwerk-Planung

### IP-Range Planung

Dein Cluster wird im VLAN mit der IP-Range **10.10.X.X** laufen. Du musst entscheiden, welches Subnetz du verwendest.

**Beispiel-Planung** (du kannst anpassen):

| Gerät | IP-Adresse | Hostname | Rolle |
|-------|------------|----------|-------|
| Master | 10.10.10.10 | k3s-master | K3S Master Node |
| Worker 1 | 10.10.10.11 | k3s-worker-1 | K3S Worker Node |
| Worker 2 | 10.10.10.12 | k3s-worker-2 | K3S Worker Node |
| Worker 3 | 10.10.10.13 | k3s-worker-3 | K3S Worker Node |
| NFS Server | 10.10.10.20 | nfs-server | NFS Storage |
| Gateway | 10.10.10.1 | gateway | Router/Gateway |

**Wichtig**: 
- Notiere dir deine gewählten IP-Adressen
- Verwende ein Subnetz mit genug Platz (z.B. /24 = 254 Hosts)
- Gateway sollte erreichbar sein

### Subnetz-Berechnung

Für ein `/24` Subnetz (255.255.255.0):
- **Netzwerk**: 10.10.10.0/24
- **Hosts**: 10.10.10.1 - 10.10.10.254
- **Gateway**: Typischerweise 10.10.10.1
- **Broadcast**: 10.10.10.255

### DNS-Planung (optional)

Falls du einen lokalen DNS-Server hast:
- [ ] DNS-Server IP-Adresse bekannt
- [ ] Hostname-Auflösung geplant
- [ ] Reverse-DNS geplant

Falls nicht: Du kannst `/etc/hosts` auf deiner Workstation verwenden.

## Software-Voraussetzungen

### Auf den Futro S740 Geräten

Nach der Kairos-Installation (siehe [Kapitel 4](04-kairos-installation.md)):
- Kairos OS (Alpine-based)
- SSH-Server (aktiviert)
- Basis-Tools (wird mit Kairos installiert)

### Auf deiner Management-Workstation

Du wirst folgende Tools installieren müssen:

#### kubectl (Kubernetes CLI)

**Was ist kubectl?**
Das Command-Line-Tool für die Interaktion mit Kubernetes-Clustern.

**Installation** (wird in [Kapitel 7](07-kubectl-basics.md) erklärt):
- Linux: `curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"`
- Mac: `brew install kubectl`
- Windows: `choco install kubernetes-cli`

#### OpenTofu

**Installation** (wird in [Kapitel 8](08-opentofu-introduction.md) erklärt):
- Download von [opentofu.org](https://opentofu.org/)
- Oder über Package Manager

#### Ansible

**Installation** (wird in [Kapitel 9](09-ansible-introduction.md) erklärt):
- Linux: `pip install ansible` oder Package Manager
- Mac: `brew install ansible`
- Windows: WSL oder pip

#### Helm

**Installation** (wird in [Kapitel 10](10-helm-introduction.md) erklärt):
- `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`
- Oder über Package Manager

#### Optional: Weitere Tools

- **k9s**: Terminal-basierte Kubernetes UI
- **jq**: JSON-Processing
- **yq**: YAML-Processing
- **git**: Version Control (empfohlen)

## NFS-Server Voraussetzungen

Da dein NFS-Server bereits vorhanden ist, überprüfe folgendes:

### NFS-Export Konfiguration

- [ ] NFS-Export ist erreichbar vom Cluster-VLAN
- [ ] Export-Pfad bekannt (z.B. `/mnt/storage/k3s`)
- [ ] NFS-Version bekannt (v3 oder v4 empfohlen)
- [ ] Zugriffsrechte verstanden (welche IPs haben Zugriff?)

### Test-Verbindung

Du kannst die NFS-Verbindung später testen mit:

```bash
# Test NFS-Mount (von einem Node aus)
showmount -e <NFS-SERVER-IP>
```

### Empfohlene NFS-Einstellungen

Für Kubernetes-Storage:
- **NFS Version**: v4 (wenn möglich) oder v3
- **Mount Options**: `rw,sync,hard,intr`
- **Permissions**: Ausreichend für Kubernetes (UID/GID Mapping beachten)

## Dokumentation vorbereiten

Erstelle eine Dokumentations-Datei für deine spezifische Konfiguration:

```yaml
# cluster-config.yaml (Beispiel - du erstellst deine eigene)
cluster:
  name: futro-cluster
  vlan: 10.10.10.0/24
  gateway: 10.10.10.1
  
nodes:
  master:
    ip: 10.10.10.10
    hostname: k3s-master
    mac: XX:XX:XX:XX:XX:XX
    
  workers:
    - ip: 10.10.10.11
      hostname: k3s-worker-1
      mac: XX:XX:XX:XX:XX:XX
    - ip: 10.10.10.12
      hostname: k3s-worker-2
      mac: XX:XX:XX:XX:XX:XX
    - ip: 10.10.10.13
      hostname: k3s-worker-3
      mac: XX:XX:XX:XX:XX:XX

storage:
  nfs:
    server: 10.10.10.20
    path: /mnt/storage/k3s
    version: v4
```

## Checkliste vor Installation

Bevor du mit [Kapitel 3: Netzwerk-Setup](03-network-setup.md) beginnst:

- [ ] Alle Hardware-Komponenten vorhanden
- [ ] IP-Adressen geplant und dokumentiert
- [ ] Switch-Zugriff vorhanden
- [ ] NFS-Server erreichbar und konfiguriert
- [ ] Management-Workstation vorbereitet
- [ ] Boot-Medium für Kairos vorbereitet (USB-Stick)
- [ ] Dokumentation deiner Konfiguration erstellt

## Häufige Fehler vermeiden

1. **IP-Konflikte**: Stelle sicher, dass deine gewählten IPs nicht bereits verwendet werden
2. **VLAN-Isolation**: Teste, dass das VLAN korrekt isoliert ist
3. **NFS-Zugriff**: Stelle sicher, dass NFS vom Cluster-VLAN erreichbar ist
4. **DNS**: Falls du DNS verwendest, teste die Auflösung vorher

## Nächste Schritte

Sobald alle Voraussetzungen erfüllt sind, geht es weiter mit [Kapitel 3: Netzwerk-Setup](03-network-setup.md), wo wir das VLAN konfigurieren und die IP-Adressen zuweisen.

## Weiterführende Ressourcen

- [Subnetz-Rechner](https://www.subnet-calculator.com/)
- [NFS Best Practices](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/storage_administration_guide/nfs-serverconfig)
- [VLAN Grundlagen](https://www.cisco.com/c/en/us/support/docs/lan-switching/8021q/17056-741-21.html)

