# Kapitel 13: Best Practices

## Übersicht

In diesem Kapitel lernst du Best Practices für den Betrieb deines Kubernetes-Clusters im Homelab. Du wirst Security, Monitoring, Backups und Wartung verstehen.

## Security

### RBAC (Role-Based Access Control)

RBAC kontrolliert, wer was im Cluster machen darf.

#### Service Account erstellen

```yaml
# service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: default
```

#### Role erstellen

```yaml
# role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

#### RoleBinding erstellen

```yaml
# role-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: ServiceAccount
  name: my-app-sa
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### Network Policies

Network Policies kontrollieren Netzwerk-Traffic zwischen Pods.

#### Beispiel Network Policy

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: default
spec:
  podSelector: {}  # Alle Pods
  policyTypes:
  - Ingress
  - Egress
  # Standard: Alles blockieren
```

#### Erlaube Traffic

```yaml
# allow-specific-traffic.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-nginx
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: nginx
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: allowed-client
    ports:
    - protocol: TCP
      port: 80
```

**Für Homelab**: Network Policies sind optional, aber gute Praxis.

### Secrets Management

#### Secrets erstellen

```bash
# Secret aus Datei
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123

# Secret aus Datei
kubectl create secret generic my-secret \
  --from-file=./password.txt
```

#### Secrets in Pods verwenden

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-secret
spec:
  containers:
  - name: app
    image: nginx
    env:
    - name: PASSWORD
      valueFrom:
        secretKeyRef:
          name: my-secret
          key: password
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secret
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: my-secret
```

**Best Practice**: Nie Passwörter in YAML-Dateien hardcoden!

### API Server Security

#### K3S API Server konfigurieren

```yaml
# /etc/rancher/k3s/config.yaml
# API Server nur auf internem Interface
bind-address: "10.10.10.10"  # Master IP
```

**Für Homelab**: VLAN-Isolation ist ausreichend, aber API Server nur intern binden ist sicherer.

## Monitoring

### Einfaches Monitoring mit kubectl

```bash
# Cluster-Status
kubectl get nodes
kubectl get pods -A

# Ressourcen-Verbrauch
kubectl top nodes
kubectl top pods

# Events
kubectl get events --sort-by='.lastTimestamp'
```

### Prometheus & Grafana (erweitert)

#### Installation mit Helm

```bash
# Repository hinzufügen
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Prometheus Stack installieren
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

**Für Homelab**: Optional, aber sehr nützlich für langfristigen Betrieb.

### Logging

#### Pod-Logs

```bash
# Logs eines Pods
kubectl logs <pod-name>

# Logs mit Follow
kubectl logs -f <pod-name>

# Logs aller Pods in Deployment
kubectl logs -f deployment/<deployment-name>
```

#### System-Logs

```bash
# K3S Logs (auf Master)
sudo journalctl -u k3s -f

# K3S Agent Logs (auf Workers)
sudo journalctl -u k3s-agent -f
```

## Backup-Strategien

### Cluster-State sichern

#### K3S State sichern

```bash
# Auf Master Node
sudo systemctl stop k3s

# State sichern
sudo tar czf k3s-state-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/rancher/k3s/server

# K3S starten
sudo systemctl start k3s
```

#### Automatisches Backup-Script

Erstelle `scripts/backup-cluster.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/backup/k3s"
DATE=$(date +%Y%m%d-%H%M%S)

# Erstelle Backup-Verzeichnis
mkdir -p $BACKUP_DIR

# Backup K3S State
ssh kairos@k3s-master "sudo tar czf - /var/lib/rancher/k3s/server" | \
  gzip > $BACKUP_DIR/k3s-state-$DATE.tar.gz

# Backup etcd (falls verwendet)
# K3S verwendet SQLite, kein etcd-Backup nötig

echo "Backup completed: $BACKUP_DIR/k3s-state-$DATE.tar.gz"
```

### Application-Backups

#### PVC-Daten sichern

```bash
# Backup PVC-Daten
kubectl exec -it <pod-name> -- tar czf - /data > backup-$(date +%Y%m%d).tar.gz

# Oder direkt vom NFS-Server
# (einfacher, da NFS direkt zugänglich)
```

#### Velero (erweitert)

Velero ist ein Tool für Kubernetes-Backups:

```bash
# Installation (erweitert, optional)
# Siehe Velero Dokumentation
```

**Für Homelab**: Manuelle Backups sind ausreichend.

## Update-Prozesse

### K3S aktualisieren

#### Master aktualisieren

```bash
# Auf Master Node
sudo systemctl stop k3s

# K3S neu installieren (neue Version)
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.5 sh -

# Oder mit Ansible (siehe Kapitel 9)
```

#### Worker aktualisieren

```bash
# Auf Worker Node
sudo systemctl stop k3s-agent

# K3S Agent neu installieren
curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.10.10.10:6443 \
  K3S_TOKEN=<token> \
  INSTALL_K3S_VERSION=v1.28.5 sh -
```

### Node-Updates

#### System-Updates mit Ansible

Erstelle `ansible/playbooks/update-nodes.yml`:

```yaml
---
- name: Update all nodes
  hosts: k3s_cluster
  become: yes
  tasks:
    - name: Update package cache
      apk:
        update_cache: yes

    - name: Upgrade packages
      apk:
        upgrade: dist
```

### Rolling Updates

Kubernetes unterstützt automatische Rolling Updates:

```bash
# Deployment aktualisieren
kubectl set image deployment/my-app my-app=my-app:v2

# Rollout-Status prüfen
kubectl rollout status deployment/my-app

# Rollback bei Problemen
kubectl rollout undo deployment/my-app
```

## Wartung

### Regelmäßige Tasks

#### Wöchentlich

- [ ] Cluster-Status prüfen (`kubectl get nodes`)
- [ ] Pod-Status prüfen (`kubectl get pods -A`)
- [ ] Logs auf Fehler prüfen
- [ ] Storage-Verbrauch prüfen

#### Monatlich

- [ ] K3S Updates prüfen
- [ ] System-Updates durchführen
- [ ] Backups verifizieren
- [ ] Security-Audit (optional)

### Node-Wartung

#### Node drainen (für Wartung)

```bash
# Pods von Node entfernen (sicher)
kubectl drain k3s-worker-1 --ignore-daemonsets --delete-emptydir-data

# Node wieder verfügbar machen
kubectl uncordon k3s-worker-1
```

#### Node entfernen

```bash
# Node drainen
kubectl drain k3s-worker-1 --ignore-daemonsets --delete-emptydir-data

# Node aus Cluster entfernen
kubectl delete node k3s-worker-1

# Auf Node: K3S deinstallieren
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

## Homelab-spezifische Tipps

### Ressourcen-Management

```yaml
# Resource Limits setzen
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
```

### Namespace-Organisation

```bash
# Namespaces für Organisation
kubectl create namespace apps
kubectl create namespace monitoring
kubectl create namespace storage
```

### Dokumentation

- **Cluster-Config**: Dokumentiere deine Konfiguration
- **Änderungen**: Notiere wichtige Änderungen
- **Probleme**: Dokumentiere Lösungen für wiederkehrende Probleme

## Performance-Optimierung

### Node-Affinity

```yaml
# Pods auf bestimmte Nodes platzieren
apiVersion: v1
kind: Pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-role
            operator: In
            values:
            - worker
```

### Resource Quotas

```yaml
# Resource Quota für Namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: default
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
```

## Checkliste

Du solltest jetzt verstehen:
- [ ] Security-Grundlagen (RBAC, Network Policies, Secrets)
- [ ] Monitoring-Optionen
- [ ] Backup-Strategien
- [ ] Update-Prozesse
- [ ] Wartungs-Prozeduren
- [ ] Homelab-spezifische Best Practices

## Nächste Schritte

Jetzt, da du Best Practices kennst, geht es weiter mit [Kapitel 14: Troubleshooting](14-troubleshooting.md), wo du lernst, wie du häufige Probleme löst.

## Weiterführende Ressourcen

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [RBAC Dokumentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Prometheus Dokumentation](https://prometheus.io/docs/)

