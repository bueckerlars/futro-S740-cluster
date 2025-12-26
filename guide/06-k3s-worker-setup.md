# Kapitel 6: K3S Worker Setup

## Übersicht

In diesem Kapitel fügst du die 3 Worker Nodes zum Cluster hinzu, verifizierst die Verbindungen und organisierst die Nodes mit Labels.

## Worker-Join-Prozess

### Was passiert beim Join?

1. Worker Node verbindet sich mit Master (API Server)
2. Authentifizierung mit Token
3. Worker registriert sich im Cluster
4. kubelet startet und meldet sich beim Master
5. Master weist Pods zu (später)

## Installation auf Worker 1

### Schritt 1: SSH-Verbindung

```bash
# Von deiner Workstation
ssh kairos@k3s-worker-1
# oder
ssh kairos@10.10.10.11
```

### Schritt 2: K3S als Worker installieren

Du benötigst:
- **Master IP**: `10.10.10.10`
- **Token**: Den Token vom Master (siehe [Kapitel 5](05-k3s-master-setup.md))

```bash
# K3S als Worker installieren
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.10.10:6443 K3S_TOKEN=<DEIN-TOKEN> sh -
```

**Ersetze `<DEIN-TOKEN>`** mit dem Token vom Master!

**Was passiert hier?**
- K3S wird als Worker installiert (nicht als Master)
- Verbindet sich mit Master auf Port 6443
- Authentifiziert mit Token
- Registriert sich im Cluster

### Schritt 3: Verifikation

```bash
# K3S Service Status
sudo systemctl status k3s-agent

# Sollte "active (running)" zeigen
# Falls nicht: Logs prüfen
sudo journalctl -u k3s-agent -f
```

### Schritt 4: Vom Master aus prüfen

```bash
# Von deiner Workstation (kubectl)
kubectl get nodes

# Sollte jetzt 2 Nodes zeigen:
# NAME          STATUS   ROLES                  AGE   VERSION
# k3s-master    Ready    control-plane,master   15m   v1.28.x
# k3s-worker-1  Ready    <none>                 1m    v1.28.x
```

## Installation auf Worker 2 und 3

Wiederhole den Prozess für die anderen Worker Nodes:

### Worker 2 (10.10.10.12)

```bash
ssh kairos@k3s-worker-2
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.10.10:6443 K3S_TOKEN=<DEIN-TOKEN> sh -
```

### Worker 3 (10.10.10.13)

```bash
ssh kairos@k3s-worker-3
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.10.10:6443 K3S_TOKEN=<DEIN-TOKEN> sh -
```

## Vollständige Cluster-Verifikation

### Alle Nodes anzeigen

```bash
# Von deiner Workstation
kubectl get nodes -o wide

# Sollte alle 4 Nodes zeigen:
# NAME           STATUS   ROLES                  AGE   VERSION   INTERNAL-IP    EXTERNAL-IP
# k3s-master     Ready    control-plane,master   20m   v1.28.x   10.10.10.10    <none>
# k3s-worker-1   Ready    <none>                 5m    v1.28.x   10.10.10.11    <none>
# k3s-worker-2   Ready    <none>                 3m    v1.28.x   10.10.10.12    <none>
# k3s-worker-3   Ready    <none>                 1m    v1.28.x   10.10.10.13    <none>
```

### Detaillierte Node-Info

```bash
# Detaillierte Info eines Workers
kubectl describe node k3s-worker-1

# Zeigt:
# - Node-Status
# - Ressourcen (CPU, RAM, Storage)
# - Labels und Annotations
# - System-Info
# - Pods auf diesem Node
```

### Cluster-Kapazität

```bash
# Verfügbare Ressourcen im Cluster
kubectl top nodes

# Zeigt CPU und Memory-Verbrauch (benötigt metrics-server, der sollte laufen)
```

## Node-Labeling

Labels helfen dir, Nodes zu organisieren und Pods gezielt zu platzieren.

### Labels hinzufügen

```bash
# Worker 1 als "worker-1" labeln
kubectl label nodes k3s-worker-1 node-role=worker node-id=worker-1

# Worker 2
kubectl label nodes k3s-worker-2 node-role=worker node-id=worker-2

# Worker 3
kubectl label nodes k3s-worker-3 node-role=worker node-id=worker-3
```

### Labels prüfen

```bash
# Alle Nodes mit Labels
kubectl get nodes --show-labels

# Sollte zeigen:
# NAME           STATUS   ROLES                  AGE   VERSION   LABELS
# k3s-master     Ready    control-plane,master   25m   v1.28.x   ...node-role.kubernetes.io/control-plane...
# k3s-worker-1   Ready    <none>                 10m   v1.28.x   ...node-id=worker-1,node-role=worker
# k3s-worker-2   Ready    <none>                 8m    v1.28.x   ...node-id=worker-2,node-role=worker
# k3s-worker-3   Ready    <none>                 5m    v1.28.x   ...node-id=worker-3,node-role=worker
```

### Labels verwenden (später)

Mit Labels kannst du später Pods auf bestimmte Nodes platzieren:

```yaml
# Beispiel (wird später erklärt)
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  nodeSelector:
    node-id: worker-1
  # ...
```

## Erster Test: Pod auf Worker starten

### Test-Pod erstellen

```bash
# Einfacher Test-Pod
kubectl run test-pod --image=nginx --restart=Never

# Pod-Status prüfen
kubectl get pods -o wide

# Sollte zeigen, auf welchem Node der Pod läuft
# NAME       READY   STATUS    RESTARTS   AGE   IP           NODE
# test-pod   1/1     Running   0          10s   10.42.x.x    k3s-worker-2
```

### Pod auf spezifischem Node starten

```bash
# Pod auf Worker 1 starten
kubectl run test-pod-1 --image=nginx --restart=Never --overrides='
{
  "spec": {
    "nodeSelector": {
      "node-id": "worker-1"
    }
  }
}'

# Prüfen
kubectl get pods -o wide
# test-pod-1 sollte auf k3s-worker-1 laufen
```

### Aufräumen

```bash
# Test-Pods löschen
kubectl delete pod test-pod test-pod-1
```

## Netzwerk-Verbindungen prüfen

### Pod-zu-Pod Kommunikation

```bash
# Pod auf Worker 1
kubectl run pod-1 --image=busybox --restart=Never --overrides='
{
  "spec": {
    "nodeSelector": {"node-id": "worker-1"},
    "containers": [{
      "name": "busybox",
      "image": "busybox",
      "command": ["sleep", "3600"]
    }]
  }
}'

# Pod auf Worker 2
kubectl run pod-2 --image=busybox --restart=Never --overrides='
{
  "spec": {
    "nodeSelector": {"node-id": "worker-2"},
    "containers": [{
      "name": "busybox",
      "image": "busybox",
      "command": ["sleep", "3600"]
    }]
  }
}'

# IP-Adressen prüfen
kubectl get pods -o wide

# Ping-Test (von pod-1 zu pod-2)
kubectl exec pod-1 -- ping -c 3 <POD-2-IP>
```

## Häufige Probleme

### Problem: Worker kann Master nicht erreichen

**Lösung**:
```bash
# Auf Worker Node
ping 10.10.10.10  # Master IP
telnet 10.10.10.10 6443  # API Server Port

# Firewall prüfen
# Netzwerk-Konfiguration prüfen
```

### Problem: Worker zeigt "NotReady"

**Lösung**:
```bash
# Auf Worker Node: Logs prüfen
sudo journalctl -u k3s-agent -n 50

# Häufige Ursachen:
# - Falscher Token
# - Master nicht erreichbar
# - Netzwerk-Problem
# - Port 6443 blockiert
```

### Problem: Token abgelehnt

**Lösung**:
1. Token nochmal vom Master kopieren
2. Sicherstellen, dass Token korrekt eingegeben wurde
3. Keine Leerzeichen oder Zeilenumbrüche im Token

## Cluster-Status zusammenfassen

### Vollständiger Status-Check

```bash
# Nodes
kubectl get nodes

# System Pods
kubectl get pods -n kube-system

# Services
kubectl get svc -A

# Cluster-Info
kubectl cluster-info
```

### Health Check Script (optional)

Erstelle ein kleines Script für regelmäßige Checks:

```bash
#!/bin/bash
# cluster-health.sh

echo "=== Cluster Nodes ==="
kubectl get nodes

echo -e "\n=== System Pods ==="
kubectl get pods -n kube-system

echo -e "\n=== Cluster Info ==="
kubectl cluster-info
```

## Checkliste

Vor dem Weitergehen zu [Kapitel 7: kubectl Grundlagen](07-kubectl-basics.md):

- [ ] Alle 3 Worker Nodes sind dem Cluster beigetreten
- [ ] Alle 4 Nodes zeigen Status "Ready"
- [ ] Nodes sind mit Labels versehen
- [ ] Test-Pod läuft erfolgreich
- [ ] Pod-zu-Pod Kommunikation funktioniert
- [ ] Cluster-Status ist gesund

## Nächste Schritte

Jetzt, da dein Cluster vollständig läuft, geht es weiter mit [Kapitel 7: kubectl Grundlagen](07-kubectl-basics.md), wo du lernst, wie du mit deinem Cluster arbeitest.

## Weiterführende Ressourcen

- [K3S Agent Installation](https://docs.k3s.io/installation/agent-options)
- [Kubernetes Node Management](https://kubernetes.io/docs/concepts/architecture/nodes/)
- [Node Labels und Selectors](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)

