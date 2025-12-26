# Kapitel 5: K3S Master Setup

## Übersicht

In diesem Kapitel installierst du K3S auf dem Master Node, generierst den Join-Token für die Worker Nodes und verifizierst die Installation.

## Was passiert bei der K3S Installation?

K3S installiert automatisch:
- **Kubernetes Control Plane**: API Server, Scheduler, Controller Manager
- **etcd Alternative**: SQLite (eingebaut, kein separater etcd-Cluster nötig)
- **Container Runtime**: containerd
- **Netzwerk**: Flannel (CNI Plugin)
- **Service Load Balancer**: Eingebauter Load Balancer

## Installation

### Schritt 1: SSH-Verbindung zum Master

```bash
# Von deiner Workstation
ssh kairos@k3s-master
# oder
ssh kairos@10.10.10.10
```

### Schritt 2: K3S installieren

K3S bietet ein einfaches Installations-Skript:

```bash
# K3S Master installieren
curl -sfL https://get.k3s.io | sh -
```

**Was passiert hier?**
- Das Skript lädt K3S herunter
- Installiert es nach `/usr/local/bin/k3s`
- Erstellt Systemd-Service
- Startet K3S automatisch

### Schritt 3: Installation verifizieren

```bash
# K3S Service Status prüfen
sudo systemctl status k3s

# Sollte "active (running)" zeigen
# Falls nicht: Logs prüfen
sudo journalctl -u k3s -f
```

### Schritt 4: K3S läuft testen

```bash
# Kubernetes API testen
sudo k3s kubectl get nodes

# Sollte den Master Node zeigen:
# NAME          STATUS   ROLES                  AGE   VERSION
# k3s-master    Ready    control-plane,master   1m    v1.28.x+k3s1
```

## Kubeconfig für externe Zugriff

### Kubeconfig kopieren

Die Kubeconfig-Datei enthält die Credentials für den Cluster-Zugriff:

```bash
# Kubeconfig anzeigen (auf Master)
sudo cat /etc/rancher/k3s/k3s.yaml
```

### Auf Workstation kopieren

```bash
# Von deiner Workstation aus
mkdir -p ~/.kube

# Kubeconfig vom Master kopieren
scp kairos@k3s-master:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Wichtig: Server-URL anpassen
# Ersetze "127.0.0.1" oder "localhost" mit der Master-IP
sed -i 's/127.0.0.1/10.10.10.10/g' ~/.kube/config
# oder
sed -i 's/localhost/10.10.10.10/g' ~/.kube/config
```

### kubectl installieren (auf Workstation)

**Linux**:
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**Mac**:
```bash
brew install kubectl
```

**Windows**:
```bash
choco install kubernetes-cli
```

### Erste kubectl-Tests

```bash
# Von deiner Workstation
kubectl get nodes

# Sollte den Master zeigen:
# NAME          STATUS   ROLES                  AGE   VERSION
# k3s-master    Ready    control-plane,master   5m    v1.28.x+k3s1

# Cluster-Info
kubectl cluster-info
```

## Join-Token für Worker Nodes

### Token anzeigen

Der Token wird benötigt, damit Worker Nodes dem Cluster beitreten können:

```bash
# Auf Master Node
sudo cat /var/lib/rancher/k3s/server/node-token
```

**Ausgabe**: Ein langer String wie `K10abc123def456...`

**Wichtig**: 
- Speichere diesen Token sicher
- Du brauchst ihn für alle 3 Worker Nodes
- Token bleibt gleich, auch wenn Worker Nodes hinzugefügt werden

### Token dokumentieren

```bash
# Auf deiner Workstation, dokumentiere den Token
echo "K3S_TOKEN=K10abc123def456..." >> ~/.cluster-secrets
chmod 600 ~/.cluster-secrets
```

## Erweiterte Konfiguration (optional)

### K3S mit spezifischen Optionen installieren

Falls du später K3S mit spezifischen Optionen installieren willst:

```bash
# Beispiel: K3S mit bestimmten Optionen
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
```

**Häufige Optionen**:
- `--disable traefik`: Deaktiviert eingebauten Ingress Controller
- `--cluster-cidr`: Custom Pod-Netzwerk CIDR
- `--service-cidr`: Custom Service-Netzwerk CIDR
- `--cluster-dns`: Custom DNS-Server

**Für jetzt**: Standard-Installation ist ausreichend.

### K3S Konfigurations-Datei

K3S Konfiguration liegt in:
- `/etc/rancher/k3s/config.yaml` (falls vorhanden)

**Beispiel-Config** (für später):
```yaml
# /etc/rancher/k3s/config.yaml
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"
cluster-dns: "10.43.0.10"
disable:
  - traefik
```

## Verifikation

### Vollständiger Cluster-Status

```bash
# Von Workstation
kubectl get nodes -o wide

# Sollte zeigen:
# NAME          STATUS   ROLES                  AGE   VERSION   INTERNAL-IP    EXTERNAL-IP
# k3s-master    Ready    control-plane,master   10m   v1.28.x   10.10.10.10     <none>
```

### System Pods prüfen

```bash
# System Pods (Control Plane)
kubectl get pods -n kube-system

# Sollte zeigen:
# NAME                                      READY   STATUS    RESTARTS   AGE
# coredns-xxx                               1/1     Running   0          5m
# local-path-provisioner-xxx                1/1     Running   0          5m
# metrics-server-xxx                        1/1     Running   0          5m
# svclb-traefik-xxx                         1/1     Running   0          5m
# traefik-xxx                               1/1     Running   0          5m
```

### API Server erreichbar

```bash
# API Server Health Check
kubectl cluster-info

# Sollte zeigen:
# Kubernetes control plane is running at https://10.10.10.10:6443
# CoreDNS is running at https://10.10.10.10:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

## Häufige Probleme

### Problem: K3S startet nicht

**Lösung**:
```bash
# Logs prüfen
sudo journalctl -u k3s -n 50

# Häufige Ursachen:
# - Port 6443 bereits belegt
# - Nicht genug RAM
# - Netzwerk-Problem
```

### Problem: kubectl funktioniert nicht von Workstation

**Lösung**:
1. Kubeconfig korrekt kopiert?
2. Server-URL in kubeconfig angepasst? (10.10.10.10 statt localhost)
3. Firewall erlaubt Port 6443?
4. kubectl installiert? (`kubectl version --client`)

### Problem: Token nicht gefunden

**Lösung**:
```bash
# Token neu generieren (falls nötig)
sudo cat /var/lib/rancher/k3s/server/node-token

# Falls Datei nicht existiert, K3S neu installieren
```

## Sicherheit (Grundlagen)

### API Server Zugriff

Standardmäßig lauscht K3S auf allen Interfaces. Für Homelab ist das OK, da VLAN isoliert ist.

**Für später** (siehe [Kapitel 13](13-best-practices.md)):
- RBAC konfigurieren
- Network Policies einrichten
- API Server nur auf internem Interface binden

## Checkliste

Vor dem Weitergehen zu [Kapitel 6: K3S Worker Setup](06-k3s-worker-setup.md):

- [ ] K3S auf Master Node installiert
- [ ] K3S Service läuft (`systemctl status k3s`)
- [ ] Master Node zeigt als Ready (`kubectl get nodes`)
- [ ] Kubeconfig auf Workstation kopiert und konfiguriert
- [ ] kubectl funktioniert von Workstation
- [ ] Join-Token notiert und gespeichert
- [ ] System Pods laufen (`kubectl get pods -n kube-system`)

## Nächste Schritte

Jetzt, da der Master Node läuft, geht es weiter mit [Kapitel 6: K3S Worker Setup](06-k3s-worker-setup.md), wo wir die 3 Worker Nodes zum Cluster hinzufügen.

## Weiterführende Ressourcen

- [K3S Installation Dokumentation](https://docs.k3s.io/installation)
- [K3S Konfiguration](https://docs.k3s.io/installation/configuration)
- [K3S Troubleshooting](https://docs.k3s.io/troubleshooting)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

