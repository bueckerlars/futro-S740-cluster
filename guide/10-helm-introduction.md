# Kapitel 10: Helm Einführung

## Übersicht

In diesem Kapitel lernst du Helm kennen, den Package Manager für Kubernetes. Du wirst verstehen, wie du komplexe Anwendungen einfach installierst und verwaltest.

## Was ist Helm?

Helm ist der Package Manager für Kubernetes, ähnlich wie `apt` für Debian oder `brew` für Mac.

### Warum Helm?

- **Einfache Installation**: Komplexe Apps mit einem Befehl
- **Templating**: Konfigurierbare Deployments
- **Versionierung**: Einfaches Upgrade/Downgrade
- **Dependency Management**: Abhängigkeiten automatisch auflösen
- **Rollback**: Einfaches Zurückrollen auf vorherige Versionen

### Helm vs. kubectl apply

| Feature | Helm | kubectl apply |
|---------|------|---------------|
| Komplexität | Einfach | Komplex |
| Templating | Ja | Nein |
| Versionierung | Eingebaut | Manuell |
| Rollback | Einfach | Manuell |
| Dependencies | Automatisch | Manuell |

## Installation

### Linux

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Mac

```bash
brew install helm
```

### Windows

```bash
choco install kubernetes-helm
```

### Verifikation

```bash
helm version
# Sollte Version anzeigen
```

## Grundlegende Konzepte

### Charts

Ein Chart ist ein Package von Kubernetes-Ressourcen.

**Beispiel**: Ein nginx-Chart enthält:
- Deployment
- Service
- ConfigMap
- etc.

### Repositories

Repositories sind Sammlungen von Charts.

**Beispiele**:
- `https://charts.bitnami.com/bitnami` (Bitnami)
- `https://kubernetes.github.io/ingress-nginx` (Ingress NGINX)
- `https://prometheus-community.github.io/helm-charts` (Prometheus)

### Releases

Ein Release ist eine installierte Instanz eines Charts.

**Beispiel**: 
- Chart: `nginx`
- Release: `my-nginx-app`

## Erste Schritte

### Repository hinzufügen

```bash
# Bitnami Repository (viele populäre Apps)
helm repo add bitnami https://charts.bitnami.com/bitnami

# Repository-Liste aktualisieren
helm repo update

# Verfügbare Repositories anzeigen
helm repo list
```

### Chart suchen

```bash
# Nach Charts suchen
helm search repo nginx

# Alle verfügbaren Charts in Repository
helm search repo bitnami
```

### Chart installieren

```bash
# Einfache Installation
helm install my-nginx bitnami/nginx

# Mit Release-Name
helm install <release-name> <chart>

# Beispiel
helm install web-server bitnami/nginx
```

### Release-Status prüfen

```bash
# Alle Releases anzeigen
helm list

# Detaillierte Info
helm status web-server

# Release-Historie
helm history web-server
```

### Release löschen

```bash
helm uninstall web-server
```

## Chart-Konfiguration

### Values-Datei

Charts verwenden Values für Konfiguration.

**Beispiel** (`values.yaml`):
```yaml
# nginx values
replicaCount: 3
image:
  repository: nginx
  tag: "1.21"
service:
  type: ClusterIP
  port: 80
```

### Installation mit Values

```bash
# Mit Values-Datei
helm install web-server bitnami/nginx -f values.yaml

# Mit inline Values
helm install web-server bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=NodePort
```

### Values anzeigen

```bash
# Default Values anzeigen
helm show values bitnami/nginx

# Aktuelle Values eines Releases
helm get values web-server
```

## Praktische Beispiele

### Beispiel 1: Nginx mit NodePort

```bash
# Installiere nginx mit NodePort
helm install nginx bitnami/nginx \
  --set service.type=NodePort \
  --set replicaCount=2

# NodePort finden
kubectl get svc nginx
```

### Beispiel 2: PostgreSQL für Datenbank

```bash
# PostgreSQL installieren
helm install postgres bitnami/postgresql \
  --set auth.postgresPassword=mysecretpassword \
  --set persistence.size=10Gi

# Passwort anzeigen (falls generiert)
helm get notes postgres
```

### Beispiel 3: Redis für Caching

```bash
# Redis installieren
helm install redis bitnami/redis \
  --set auth.enabled=true \
  --set auth.password=redispassword
```

## Erweiterte Konzepte

### Chart-Updates

```bash
# Chart aktualisieren
helm upgrade nginx bitnami/nginx \
  --set replicaCount=5

# Mit Values-Datei
helm upgrade nginx bitnami/nginx -f values.yaml

# Repository vorher aktualisieren
helm repo update
helm upgrade nginx bitnami/nginx
```

### Rollback

```bash
# Release-Historie anzeigen
helm history nginx

# Zu vorheriger Version zurückrollen
helm rollback nginx 1

# Zu spezifischer Revision
helm rollback nginx 2
```

### Custom Values-Datei

Erstelle `nginx-values.yaml`:

```yaml
# nginx-values.yaml
replicaCount: 3

image:
  repository: nginx
  tag: "1.21"

service:
  type: NodePort
  port: 80

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

Installation:
```bash
helm install nginx bitnami/nginx -f nginx-values.yaml
```

## Eigene Charts erstellen

### Chart-Struktur

```bash
# Neues Chart erstellen
helm create my-app

# Struktur:
my-app/
├── Chart.yaml          # Chart-Metadaten
├── values.yaml         # Default Values
├── templates/          # Kubernetes-Manifeste
│   ├── deployment.yaml
│   ├── service.yaml
│   └── _helpers.tpl    # Template-Helpers
└── charts/             # Dependencies
```

### Beispiel: Einfaches Chart

**Chart.yaml**:
```yaml
apiVersion: v2
name: my-app
description: A simple application
version: 0.1.0
type: application
```

**values.yaml**:
```yaml
replicaCount: 1

image:
  repository: nginx
  tag: "1.21"

service:
  type: ClusterIP
  port: 80
```

**templates/deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-app.fullname" . }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "my-app.name" . }}
  template:
    metadata:
      labels:
        app: {{ include "my-app.name" . }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - containerPort: 80
```

**templates/service.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "my-app.fullname" . }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80
  selector:
    app: {{ include "my-app.name" . }}
```

### Chart installieren

```bash
# Chart testen (dry-run)
helm install my-app ./my-app --dry-run --debug

# Chart installieren
helm install my-app ./my-app

# Mit custom Values
helm install my-app ./my-app -f custom-values.yaml
```

## Best Practices

### 1. Values dokumentieren

```yaml
# values.yaml
# Number of replicas
replicaCount: 3

# Image configuration
image:
  # Image repository
  repository: nginx
  # Image tag
  tag: "1.21"
```

### 2. Sensible Daten in Secrets

```yaml
# Verwende Kubernetes Secrets, nicht Values
# values.yaml
database:
  host: db.example.com
  # Passwort in Secret, nicht hier!
```

### 3. Versionierung

```bash
# Chart versionieren
helm package my-app

# Erstellt: my-app-0.1.0.tgz

# Version in Chart.yaml erhöhen
# version: 0.1.1
```

### 4. Testing

```bash
# Template testen
helm template my-app ./my-app

# Dry-run
helm install my-app ./my-app --dry-run --debug
```

## Für deinen Cluster

### Empfohlene Charts für Homelab

1. **Ingress Controller**: 
   ```bash
   helm install ingress-nginx ingress-nginx/ingress-nginx
   ```

2. **Monitoring** (Prometheus/Grafana):
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install prometheus prometheus-community/kube-prometheus-stack
   ```

3. **Storage**: 
   - NFS Provisioner (siehe [Kapitel 12](12-storage-nfs.md))

4. **Self-Hosting Apps**:
   - Nextcloud
   - GitLab
   - Jellyfin
   - etc.

### Workflow

1. **Repository hinzufügen**: `helm repo add ...`
2. **Repository aktualisieren**: `helm repo update`
3. **Chart suchen**: `helm search repo ...`
4. **Values anpassen**: `helm show values ...`
5. **Installieren**: `helm install ...`
6. **Verwalten**: `helm upgrade`, `helm rollback`

## Übungen

### Übung 1: Einfache App installieren

1. Installiere nginx mit Helm
2. Konfiguriere NodePort
3. Teste den Zugriff
4. Skaliere auf 3 Replicas

### Übung 2: Eigener Chart

1. Erstelle ein einfaches Chart
2. Definiere Values
3. Installiere das Chart
4. Teste Updates und Rollbacks

## Checkliste

Du solltest jetzt verstehen:
- [ ] Was Helm ist und wofür es verwendet wird
- [ ] Grundlegende Konzepte (Charts, Repositories, Releases)
- [ ] Wie du Charts installierst und verwaltest
- [ ] Wie du Values konfigurierst
- [ ] Wie du eigene Charts erstellst

## Nächste Schritte

Jetzt, da du Helm kennst, geht es weiter mit [Kapitel 11: IaC für Cluster-Management](11-iac-cluster-management.md), wo du lernst, wie du alle Tools zusammen verwendest.

## Weiterführende Ressourcen

- [Helm Dokumentation](https://helm.sh/docs/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Artifact Hub](https://artifacthub.io/) (Chart-Suche)
- [Helm Chart Template Guide](https://helm.sh/docs/chart_template_guide/)

