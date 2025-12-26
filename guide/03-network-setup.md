# Kapitel 3: Netzwerk-Setup

## Übersicht

In diesem Kapitel konfigurierst du das VLAN am Switch, planst die IP-Allokation und testest die Netzwerk-Verbindungen zwischen allen Geräten.

## VLAN-Grundlagen

### Was ist ein VLAN?

Ein VLAN (Virtual LAN) teilt ein physisches Netzwerk in logische Netzwerke auf. Für deinen Cluster bedeutet das:

- **Isolation**: Der Cluster ist vom Rest deines Netzwerks getrennt
- **Sicherheit**: Kein direkter Zugriff von anderen Netzwerken
- **Organisation**: Klare Trennung der Netzwerk-Bereiche

### Warum ein eigenes VLAN?

- **Sicherheit**: Kubernetes-API sollte nicht öffentlich erreichbar sein
- **Organisation**: Klare Netzwerk-Struktur
- **Flexibilität**: Einfaches Routing zwischen VLANs wenn nötig

## Switch-Konfiguration

### Allgemeine Anleitung

Die genaue Konfiguration hängt von deinem Switch-Modell ab. Hier die allgemeinen Schritte:

#### 1. Zugriff auf den Switch

- **Web-Interface**: Öffne `http://<switch-ip>` im Browser
- **SSH/Telnet**: `ssh admin@<switch-ip>`
- **Seriell**: Falls kein Netzwerk-Zugriff möglich

#### 2. VLAN erstellen

**Typische Schritte** (kann je nach Switch variieren):

1. Navigiere zu "VLAN" oder "Switching" → "VLAN"
2. Erstelle ein neues VLAN (z.B. VLAN ID 10)
3. Benenne es (z.B. "k3s-cluster")
4. Speichere die Konfiguration

**VLAN ID**: Wähle eine ID zwischen 1-4094 (1 ist meist Standard, verwende z.B. 10, 20, etc.)

#### 3. Ports zum VLAN zuweisen

**Access Ports** (für die Futro S740):
- Port 1 → Master Node
- Port 2 → Worker 1
- Port 3 → Worker 2
- Port 4 → Worker 3
- Port 5 → NFS Server (falls im selben VLAN)

**Tagged/Trunk Ports** (falls nötig):
- Port für Router/Gateway (falls VLAN-Routing nötig)

**Konfiguration**:
- Setze Ports auf "Access Mode" für das neue VLAN
- Oder "Tagged" falls der Port mehrere VLANs trägt

#### 4. Beispiel-Konfiguration (Cisco-ähnlich)

```bash
# Beispiel CLI-Kommandos (kann bei deinem Switch anders sein)
configure terminal
vlan 10
 name k3s-cluster
exit

interface range gigabitethernet 0/1-4
 switchport mode access
 switchport access vlan 10
exit

write memory
```

#### 5. Switch-spezifische Dokumentation

Da jeder Switch anders ist:
- [ ] Konsultiere die Dokumentation deines Switches
- [ ] Notiere dir die verwendete VLAN ID
- [ ] Dokumentiere die Port-Zuordnung

### Häufige Switch-Hersteller

- **Cisco**: Web-Interface oder CLI (IOS)
- **Netgear**: Web-Interface (Smart/Managed Switches)
- **TP-Link**: Web-Interface (JetStream Serie)
- **Ubiquiti**: UniFi Controller oder Web-Interface

## IP-Allokation Planung

### Subnetz-Auswahl

Basierend auf deiner Planung aus [Kapitel 2](02-prerequisites.md):

**Empfohlene Konfiguration**:

```
Netzwerk:     10.10.10.0/24
Subnetz-Maske: 255.255.255.0
Gateway:      10.10.10.1
Broadcast:    10.10.10.255
Verfügbare IPs: 10.10.10.2 - 10.10.10.254
```

### IP-Zuordnung

| Gerät | IP-Adresse | Hostname | MAC-Adresse | Port |
|-------|------------|----------|-------------|------|
| Gateway | 10.10.10.1 | gateway | - | - |
| Master | 10.10.10.10 | k3s-master | XX:XX:XX:XX:XX:XX | Port 1 |
| Worker 1 | 10.10.10.11 | k3s-worker-1 | XX:XX:XX:XX:XX:XX | Port 2 |
| Worker 2 | 10.10.10.12 | k3s-worker-2 | XX:XX:XX:XX:XX:XX | Port 3 |
| Worker 3 | 10.10.10.13 | k3s-worker-3 | XX:XX:XX:XX:XX:XX | Port 4 |
| NFS Server | 10.10.10.20 | nfs-server | XX:XX:XX:XX:XX:XX | Port 5 |

**Wichtig**:
- Notiere dir die MAC-Adressen (findest du auf den Geräten oder im Switch)
- Verwende statische IPs (kein DHCP für Cluster-Nodes)
- Lasse Platz für zukünftige Geräte

### Warum statische IPs?

- **Stabilität**: IPs ändern sich nicht
- **Konfiguration**: Einfacher in Config-Files zu verwenden
- **DNS**: Einfacheres Hostname-Mapping
- **Troubleshooting**: Vorhersehbare Netzwerk-Topologie

## Netzwerk-Tests

### Vor der Installation

Bevor du Kairos installierst, teste die Netzwerk-Verbindungen:

#### 1. Switch-Konnektivität testen

```bash
# Von deiner Workstation aus (falls im selben VLAN)
ping 10.10.10.1  # Gateway
```

#### 2. Port-Tests

- [ ] Alle 4 Futro S740 sind physisch verbunden
- [ ] Link-LEDs am Switch leuchten
- [ ] Port-Status im Switch zeigt "Up"

#### 3. VLAN-Isolation testen

Nach der Installation (siehe [Kapitel 4](04-kairos-installation.md)):

```bash
# Von einem Node aus
ping 10.10.10.10  # Master
ping 10.10.10.11  # Worker 1
ping 10.10.10.12  # Worker 2
ping 10.10.10.13  # Worker 3
ping 10.10.10.20  # NFS Server
```

#### 4. Gateway-Test

```bash
# Von einem Node aus
ping 10.10.10.1   # Gateway
ping 8.8.8.8      # Internet (falls Gateway konfiguriert)
```

### Nach der Installation

Sobald Kairos installiert ist (siehe [Kapitel 4](04-kairos-installation.md)):

#### Vollständiger Konnektivitäts-Test

```bash
# Auf jedem Node ausführen
# 1. Eigene IP prüfen
ip addr show

# 2. Gateway erreichbar
ping -c 3 10.10.10.1

# 3. Alle anderen Nodes erreichbar
ping -c 3 10.10.10.10  # Master
ping -c 3 10.10.10.11  # Worker 1
ping -c 3 10.10.10.12  # Worker 2
ping -c 3 10.10.10.13  # Worker 3

# 4. NFS Server erreichbar
ping -c 3 10.10.10.20

# 5. DNS-Test (falls konfiguriert)
nslookup k3s-master
```

## Routing (optional)

### Inter-VLAN Routing

Falls du vom Rest deines Netzwerks auf den Cluster zugreifen willst:

1. **Router konfigurieren**: Routing-Regel zwischen VLANs
2. **Firewall-Regeln**: Nur notwendige Ports öffnen
3. **VPN-Zugriff**: Sicherer Zugriff von außen

### Empfohlene Ports

Für Kubernetes-Zugriff (später):
- **6443**: Kubernetes API Server
- **10250**: kubelet API
- **8472**: Flannel VXLAN (K3S)

**Wichtig**: Öffne diese Ports nur wenn nötig und nur für vertrauenswürdige Netzwerke!

## Dokumentation

Dokumentiere deine Netzwerk-Konfiguration:

```yaml
# network-config.yaml (Beispiel)
network:
  vlan:
    id: 10
    name: k3s-cluster
    subnet: 10.10.10.0/24
    gateway: 10.10.10.1
    
  switch:
    model: "Your Switch Model"
    management_ip: "192.168.1.X"
    ports:
      - port: 1
        device: k3s-master
        vlan: 10
      - port: 2
        device: k3s-worker-1
        vlan: 10
      # ... weitere Ports
      
  dns:
    primary: "10.10.10.1"  # oder dein DNS-Server
    search_domains: ["cluster.local"]
```

## Häufige Probleme

### Problem: Nodes können sich nicht erreichen

**Lösung**:
1. VLAN-Konfiguration am Switch prüfen
2. Ports sind im richtigen VLAN?
3. Firewall-Regeln prüfen
4. IP-Adressen korrekt konfiguriert?

### Problem: Kein Internet-Zugriff

**Lösung**:
1. Gateway erreichbar? (`ping 10.10.10.1`)
2. Routing-Regel am Router/Gateway?
3. DNS konfiguriert?

### Problem: NFS nicht erreichbar

**Lösung**:
1. NFS-Server im selben VLAN?
2. Firewall auf NFS-Server erlaubt Zugriff?
3. NFS-Dienst läuft? (`systemctl status nfs-server`)

## Checkliste

Vor dem Weitergehen zu [Kapitel 4: Kairos Installation](04-kairos-installation.md):

- [ ] VLAN am Switch erstellt und konfiguriert
- [ ] Ports zum VLAN zugewiesen
- [ ] IP-Adressen geplant und dokumentiert
- [ ] MAC-Adressen notiert
- [ ] Switch-Konfiguration gespeichert
- [ ] Netzwerk-Tests vorbereitet (werden nach Installation durchgeführt)

## Nächste Schritte

Jetzt, da das Netzwerk konfiguriert ist, geht es weiter mit [Kapitel 4: Kairos Installation](04-kairos-installation.md), wo wir das Betriebssystem auf allen 4 Geräten installieren.

## Weiterführende Ressourcen

- [VLAN Konfiguration Guide](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst2960/software/release/12-2_55_se/configuration/guide/scg_2960/swvlan.html)
- [Subnetz-Berechnung](https://www.subnet-calculator.com/)
- [Netzwerk-Troubleshooting](https://www.cyberciti.biz/faq/linux-ip-command-examples-usage-syntax/)

