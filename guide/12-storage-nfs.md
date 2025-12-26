# Kapitel 12: Storage (NFS)

## Übersicht

In diesem Kapitel lernst du, wie du NFS-Storage in deinem Kubernetes-Cluster einrichtest. Du wirst Storage Classes, Persistent Volumes und Persistent Volume Claims verstehen und konfigurieren.

## Kubernetes Storage Konzepte

### Persistent Volumes (PV)

Ein Persistent Volume ist ein Storage-Segment im Cluster, das von einem Administrator bereitgestellt wurde.

### Persistent Volume Claims (PVC)

Ein Persistent Volume Claim ist eine Anfrage eines Pods nach Storage. Kubernetes weist automatisch ein passendes PV zu.

### Storage Classes

Storage Classes ermöglichen dynamische Provisionierung von Storage. Du definierst eine Storage Class, und Kubernetes erstellt automatisch PVs, wenn PVCs erstellt werden.

## NFS Storage Class

### NFS Subdir External Provisioner

Für dynamische NFS-Provisionierung verwenden wir den NFS Subdir External Provisioner.

**Was macht er?**
- Erstellt automatisch PVs für PVCs
- Nutzt deinen vorhandenen NFS-Server
- Erstellt Unterverzeichnisse für jeden PVC

### Installation mit Helm

```bash
# Repository hinzufügen
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

# Repository aktualisieren
helm repo update
```

### Values-Datei erstellen

Erstelle `helm/values/nfs-provisioner.yaml`:

```yaml
# nfs-provisioner.yaml
nfs:
  server: 10.10.10.20  # Dein NFS Server
  path: /mnt/storage/k3s  # NFS Export Path

storageClass:
  name: nfs-storage
  defaultClass: true  # Als Standard Storage Class
  reclaimPolicy: Retain  # PVs werden nicht gelöscht

# Provisioner Konfiguration
provisionerName: cluster.local/nfs-subdir-external-provisioner
```

### Installation

```bash
# NFS Provisioner installieren
helm install nfs-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  -f helm/values/nfs-provisioner.yaml \
  --namespace kube-system \
  --create-namespace
```

### Verifikation

```bash
# Storage Class prüfen
kubectl get storageclass

# Sollte zeigen:
# NAME            PROVISIONER                                   RECLAIMPOLICY   VOLUMEBINDINGMODE
# nfs-storage     cluster.local/nfs-subdir-external-provisioner   Retain          Immediate

# Provisioner Pod prüfen
kubectl get pods -n kube-system | grep nfs
```

## Persistent Volume Claim erstellen

### Beispiel PVC

Erstelle `k8s/pvc-example.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteMany  # NFS unterstützt ReadWriteMany
  storageClassName: nfs-storage
  resources:
    requests:
      storage: 10Gi
```

### PVC anwenden

```bash
# PVC erstellen
kubectl apply -f k8s/pvc-example.yaml

# PVC Status prüfen
kubectl get pvc

# Sollte zeigen:
# NAME      STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# my-pvc    Bound    pvc-xxx  10Gi       RWX            nfs-storage    5s

# Automatisch erstelltes PV prüfen
kubectl get pv
```

## Pod mit PVC verwenden

### Beispiel: Pod mit Storage

Erstelle `k8s/pod-with-storage.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-storage
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: my-pvc
```

### Pod erstellen und testen

```bash
# Pod erstellen
kubectl apply -f k8s/pod-with-storage.yaml

# In Pod einsteigen
kubectl exec -it pod-with-storage -- /bin/sh

# Im Pod: Datei erstellen
echo "Hello from Pod" > /data/test.txt
exit

# Pod löschen
kubectl delete pod pod-with-storage

# Neuen Pod mit gleichem PVC erstellen
kubectl apply -f k8s/pod-with-storage.yaml

# Datei sollte noch existieren
kubectl exec pod-with-storage -- cat /data/test.txt
# Sollte "Hello from Pod" zeigen
```

## Deployment mit Storage

### Beispiel: Deployment mit PVC

Erstelle `k8s/deployment-with-storage.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-storage
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-with-storage
  template:
    metadata:
      labels:
        app: app-with-storage
    spec:
      containers:
      - name: app
        image: nginx
        volumeMounts:
        - name: storage
          mountPath: /data
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: my-pvc
```

**Wichtig**: Mit `ReadWriteMany` können mehrere Pods gleichzeitig auf das gleiche Volume zugreifen.

## Praktische Beispiele

### Beispiel 1: Database mit Storage

```yaml
# postgres-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce  # Database braucht ReadWriteOnce
  storageClassName: nfs-storage
  resources:
    requests:
      storage: 20Gi
```

```yaml
# postgres-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:14
        env:
        - name: POSTGRES_PASSWORD
          value: "mypassword"
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgres-pvc
```

### Beispiel 2: File Server mit Storage

```yaml
# fileserver-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fileserver-pvc
spec:
  accessModes:
    - ReadWriteMany  # Mehrere Pods können zugreifen
  storageClassName: nfs-storage
  resources:
    requests:
      storage: 50Gi
```

## Storage mit Helm

### Values für App mit Storage

Erstelle `helm/values/app-with-storage.yaml`:

```yaml
# App Configuration
replicaCount: 2

# Storage Configuration
persistence:
  enabled: true
  storageClass: nfs-storage
  accessMode: ReadWriteMany
  size: 10Gi
```

### Chart mit Storage

Viele Helm Charts unterstützen Storage-Konfiguration:

```bash
# Beispiel: Installiere App mit Storage
helm install my-app bitnami/nginx \
  --set persistence.enabled=true \
  --set persistence.storageClass=nfs-storage \
  --set persistence.size=10Gi
```

## Storage Management

### PVCs anzeigen

```bash
# Alle PVCs
kubectl get pvc

# Detaillierte Info
kubectl describe pvc my-pvc

# PVCs in Namespace
kubectl get pvc -n my-namespace
```

### PVs anzeigen

```bash
# Alle PVs
kubectl get pv

# Detaillierte Info
kubectl describe pv <pv-name>
```

### Storage verwalten

```bash
# PVC löschen (PV bleibt erhalten bei Retain Policy)
kubectl delete pvc my-pvc

# PV manuell löschen (falls nötig)
kubectl delete pv <pv-name>
```

## Best Practices

### 1. Access Modes wählen

- **ReadWriteOnce (RWO)**: Ein Pod kann schreiben, mehrere können lesen
- **ReadWriteMany (RWX)**: Mehrere Pods können schreiben (NFS unterstützt das)
- **ReadOnlyMany (ROX)**: Mehrere Pods können nur lesen

### 2. Storage-Größen planen

- Starte klein und skaliere bei Bedarf
- Überwache Storage-Verbrauch
- Nutze Retention Policies

### 3. Backup-Strategie

```bash
# PVC-Daten sichern (Beispiel)
kubectl exec -it <pod-name> -- tar czf - /data > backup.tar.gz

# Oder direkt vom NFS-Server
# (einfacher, da NFS direkt zugänglich)
```

### 4. Monitoring

```bash
# Storage-Verbrauch prüfen
kubectl top pv  # Falls verfügbar

# Oder direkt auf NFS-Server
df -h /mnt/storage/k3s
```

## Troubleshooting

### Problem: PVC bleibt im Pending-Status

**Lösung**:
```bash
# PVC Details prüfen
kubectl describe pvc my-pvc

# Häufige Ursachen:
# - NFS Server nicht erreichbar
# - Falscher NFS-Pfad
# - Provisioner läuft nicht
```

### Problem: Pod kann nicht auf PVC zugreifen

**Lösung**:
```bash
# Pod Events prüfen
kubectl describe pod <pod-name>

# NFS-Mount testen (auf Node)
showmount -e 10.10.10.20

# Provisioner Logs
kubectl logs -n kube-system -l app=nfs-subdir-external-provisioner
```

### Problem: Daten gehen verloren

**Lösung**:
- Prüfe Reclaim Policy (Retain vs. Delete)
- Backup-Strategie implementieren
- NFS-Server Backup prüfen

## NFS-Server Konfiguration (Referenz)

Falls du den NFS-Server selbst konfigurieren musst:

### Linux NFS Server

```bash
# NFS Server installieren
sudo apt install nfs-kernel-server  # Debian/Ubuntu
sudo yum install nfs-utils  # RHEL/CentOS

# Export konfigurieren
echo "/mnt/storage/k3s 10.10.10.0/24(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports

# NFS Server starten
sudo systemctl enable nfs-kernel-server
sudo systemctl start nfs-kernel-server

# Exports anzeigen
sudo exportfs -v
```

## Checkliste

Du solltest jetzt verstehen:
- [ ] Was Persistent Volumes und Claims sind
- [ ] Wie Storage Classes funktionieren
- [ ] Wie du NFS-Storage einrichtest
- [ ] Wie du PVCs in Pods verwendest
- [ ] Best Practices für Storage

## Nächste Schritte

Jetzt, da Storage eingerichtet ist, geht es weiter mit [Kapitel 13: Best Practices](13-best-practices.md), wo du lernst, wie du deinen Cluster sicher und wartbar betreibst.

## Weiterführende Ressourcen

- [Kubernetes Storage Dokumentation](https://kubernetes.io/docs/concepts/storage/)
- [NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)

