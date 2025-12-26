# Kapitel 4: Kairos Installation

## Übersicht

In diesem Kapitel installierst du Kairos (Alpine-based) auf allen 4 Futro S740 Geräten und konfigurierst die Basis-Einstellungen.

## Was ist Kairos?

Kairos ist ein immutables, container-natives Betriebssystem, das speziell für Edge Computing und Cloud-Native-Workloads entwickelt wurde.

### Immutable OS - Was bedeutet das?

- **Schreibgeschützt**: Das Root-Dateisystem ist schreibgeschützt
- **Atomare Updates**: Updates werden als Ganzes installiert, nicht inkrementell
- **Rollback**: Einfaches Zurückrollen auf vorherige Version
- **Konsistenz**: Alle Systeme sind identisch

### Warum Kairos für unseren Cluster?

- **Minimaler Footprint**: Sehr wenig Ressourcenverbrauch
- **Cloud-Init**: Einfache Konfiguration über YAML
- **Alpine-basiert**: Bekanntes, sicheres Basis-System
- **Edge-optimiert**: Perfekt für ressourcenarme Hardware

## Vorbereitung

### Download Kairos Image

1. Gehe zu [Kairos Releases](https://github.com/kairos-io/kairos/releases)
2. Wähle die neueste stabile Version
3. Lade das Image für deine Architektur herunter (wahrscheinlich `amd64`)
4. Image-Format: `.iso` oder `.raw` (für USB-Stick)

**Empfohlene Version**: Neueste stabile Alpine-basierte Version

### Boot-Medium erstellen

#### Linux/Mac

```bash
# USB-Stick identifizieren (VORSICHT: richtigen Device wählen!)
lsblk  # Linux
diskutil list  # Mac

# Image auf USB-Stick schreiben
sudo dd if=kairos-<version>.iso of=/dev/sdX bs=4M status=progress
# oder
sudo dd if=kairos-<version>.iso of=/dev/diskX bs=4M status=progress  # Mac
```

#### Windows

- Verwende [Rufus](https://rufus.ie/) oder [balenaEtcher](https://www.balena.io/etcher/)
- Wähle das Kairos ISO-Image
- Schreibe auf USB-Stick

### Cloud-Init Konfiguration vorbereiten

Erstelle eine `cloud-init.yaml` Datei für die Basis-Konfiguration:

```yaml
# cloud-init.yaml (Beispiel - du erstellst deine eigene)
hostname: k3s-master  # oder k3s-worker-1, etc.
users:
  - name: kairos
    passwd: <hashed-password>  # Erstelle mit: openssl passwd -1
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2E...  # Dein SSH Public Key
    groups:
      - sudo
      - docker
      - wheel

# Netzwerk-Konfiguration
stages:
  initramfs:
    - name: "Setup network"
      commands:
        - |
          cat > /oem/01_custom.yaml << 'EOF'
          name: "Default network"
          type: network
          config:
            - type: physical
              name: eth0
              addresses:
                - 10.10.10.10/24  # Anpassen für jeden Node
              gateway: 10.10.10.1
              dns_nameservers:
                - 10.10.10.1
          EOF
```

**Wichtig**: 
- Erstelle eine separate Config für jeden Node (unterschiedliche IPs/Hostnames)
- Verwende SSH-Keys statt Passwörtern (sicherer)
- Teste die Config vor der Installation

## Installation auf Master Node

### Schritt 1: Boot vom USB-Stick

1. Stecke USB-Stick in den Master Node
2. Boot vom USB-Stick (BIOS/UEFI Boot-Menü)
3. Warte bis Kairos bootet

### Schritt 2: Installation starten

Kairos bietet verschiedene Installations-Modi:

#### Option A: Interaktive Installation

```bash
# Im Kairos Terminal
kairos-agent install
```

Folge den Anweisungen:
- Wähle Installations-Ziel (eMMC/SSD)
- Bestätige Installation
- Warte bis Installation abgeschlossen

#### Option B: Automatische Installation mit Cloud-Init

```bash
# Cloud-Init Config auf USB-Stick oder über Netzwerk
kairos-agent install --cloud-init /path/to/cloud-init.yaml
```

### Schritt 3: Cloud-Init Config anwenden

Falls du Cloud-Init verwendet hast, wird die Konfiguration automatisch angewendet. Sonst:

1. Nach Installation: System neu starten
2. Cloud-Init läuft beim ersten Boot
3. Netzwerk wird konfiguriert
4. SSH-Zugriff wird eingerichtet

### Schritt 4: Verifikation

Nach dem Neustart:

```bash
# SSH-Verbindung (von deiner Workstation)
ssh kairos@10.10.10.10  # Master IP

# Hostname prüfen
hostname  # sollte k3s-master sein

# IP-Adresse prüfen
ip addr show eth0  # sollte 10.10.10.10 sein

# Netzwerk-Test
ping -c 3 10.10.10.1  # Gateway
ping -c 3 8.8.8.8     # Internet (falls konfiguriert)
```

## Installation auf Worker Nodes

Wiederhole die Installation für alle 3 Worker Nodes:

### Worker 1 (10.10.10.11)

1. Erstelle `cloud-init-worker-1.yaml`:
   - Hostname: `k3s-worker-1`
   - IP: `10.10.10.11/24`
   - Gleiche User-Konfiguration

2. Installation wie beim Master

3. Verifikation:
```bash
ssh kairos@10.10.10.11
hostname  # sollte k3s-worker-1 sein
ip addr show eth0  # sollte 10.10.10.11 sein
```

### Worker 2 (10.10.10.12)

- Hostname: `k3s-worker-2`
- IP: `10.10.10.12/24`

### Worker 3 (10.10.10.13)

- Hostname: `k3s-worker-3`
- IP: `10.10.10.13/24`

## Basis-Konfiguration

### SSH-Zugriff einrichten

Auf jedem Node:

```bash
# SSH-Konfiguration prüfen
sudo systemctl status sshd

# Falls nicht aktiv:
sudo systemctl enable sshd
sudo systemctl start sshd
```

### System-Updates

```bash
# Kairos verwendet apk (Alpine Package Manager)
# Updates werden über Kairos-Updates gemacht, nicht über apk

# System-Info prüfen
kairos-agent version
```

### Firewall (optional)

Kairos kommt mit minimaler Firewall. Für später (Kubernetes):

```bash
# Falls du eine Firewall brauchst, installiere ufw oder ähnlich
# Aber: Kubernetes braucht viele offene Ports, Firewall kann kompliziert werden
# Für Homelab: Oft nicht nötig, da VLAN bereits isoliert
```

### NFS-Client vorbereiten

Für später (Storage, siehe [Kapitel 12](12-storage-nfs.md)):

```bash
# NFS-Client-Tools sind meist schon installiert
# Test NFS-Verbindung
showmount -e 10.10.10.20  # NFS Server IP
```

## Verifikation aller Nodes

Von deiner Workstation aus:

```bash
# Erstelle /etc/hosts Einträge (oder verwende DNS)
cat >> /etc/hosts << EOF
10.10.10.10 k3s-master
10.10.10.11 k3s-worker-1
10.10.10.12 k3s-worker-2
10.10.10.13 k3s-worker-3
10.10.10.20 nfs-server
EOF

# Test SSH-Verbindungen
for node in k3s-master k3s-worker-1 k3s-worker-2 k3s-worker-3; do
  echo "Testing $node..."
  ssh kairos@$node "hostname && ip addr show eth0 | grep inet"
done
```

## Häufige Probleme

### Problem: Boot vom USB-Stick funktioniert nicht

**Lösung**:
1. BIOS/UEFI Boot-Reihenfolge prüfen
2. Secure Boot deaktivieren (falls nötig)
3. USB-Stick auf anderem Gerät testen
4. Anderes Boot-Medium versuchen

### Problem: Netzwerk funktioniert nicht nach Installation

**Lösung**:
1. Cloud-Init Config prüfen (YAML-Syntax)
2. Manuell konfigurieren:
```bash
sudo ip addr add 10.10.10.10/24 dev eth0
sudo ip route add default via 10.10.10.1
```
3. Dauerhaft in Cloud-Init Config fixen

### Problem: SSH-Zugriff funktioniert nicht

**Lösung**:
1. SSH-Service prüfen: `sudo systemctl status sshd`
2. Firewall prüfen (falls aktiv)
3. SSH-Key korrekt in Cloud-Init?
4. Passwort-Login temporär aktivieren zum Debuggen

## Checkliste

Vor dem Weitergehen zu [Kapitel 5: K3S Master Setup](05-k3s-master-setup.md):

- [ ] Kairos auf allen 4 Nodes installiert
- [ ] Alle Nodes haben korrekte IP-Adressen
- [ ] Alle Nodes haben korrekte Hostnames
- [ ] SSH-Zugriff funktioniert auf allen Nodes
- [ ] Netzwerk-Verbindungen zwischen allen Nodes getestet
- [ ] Gateway und Internet-Zugriff funktionieren
- [ ] NFS-Server ist erreichbar (optional, wird später benötigt)

## Nächste Schritte

Jetzt, da alle Nodes mit Kairos laufen, geht es weiter mit [Kapitel 5: K3S Master Setup](05-k3s-master-setup.md), wo wir K3S auf dem Master Node installieren.

## Weiterführende Ressourcen

- [Kairos Dokumentation](https://kairos.io/docs/)
- [Kairos Installation Guide](https://kairos.io/docs/installation/)
- [Cloud-Init Dokumentation](https://cloudinit.readthedocs.io/)
- [Alpine Linux Dokumentation](https://wiki.alpinelinux.org/)

