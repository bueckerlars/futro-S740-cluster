# Kapitel 7: kubectl Grundlagen

## Übersicht

In diesem Kapitel lernst du kubectl, das Command-Line-Tool für Kubernetes, kennen. Du wirst die wichtigsten Befehle lernen und verstehen, wie du mit deinem Cluster interagierst.

## Was ist kubectl?

kubectl (Kubernetes Control) ist das offizielle Command-Line-Tool für die Interaktion mit Kubernetes-Clustern. Es ist dein Hauptwerkzeug für:
- Cluster-Verwaltung
- Deployment von Anwendungen
- Debugging und Troubleshooting
- Ressourcen-Verwaltung

## Installation (falls noch nicht geschehen)

### Linux

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Mac

```bash
brew install kubectl
```

### Windows

```bash
choco install kubernetes-cli
```

### Verifikation

```bash
kubectl version --client
# Sollte Version anzeigen
```

## Konfiguration

### Kubeconfig

kubectl verwendet eine Konfigurations-Datei (`~/.kube/config`), die du bereits in [Kapitel 5](05-k3s-master-setup.md) erstellt hast.

```bash
# Aktuelle Konfiguration anzeigen
kubectl config view

# Aktuellen Context anzeigen
kubectl config current-context

# Verfügbare Contexts
kubectl config get-contexts
```

### Kontext wechseln (falls mehrere Cluster)

```bash
# Context wechseln
kubectl config use-context <context-name>

# Für jetzt: Du hast nur einen Cluster, also kein Wechsel nötig
```

## Grundlegende Befehle

### Cluster-Info

```bash
# Cluster-Informationen
kubectl cluster-info

# Detaillierte Cluster-Info
kubectl cluster-info dump
```

### Nodes verwalten

```bash
# Alle Nodes anzeigen
kubectl get nodes

# Detaillierte Node-Info
kubectl describe node <node-name>

# Node-Info in YAML
kubectl get node <node-name> -o yaml

# Node-Info in JSON
kubectl get node <node-name> -o json
```

### Ressourcen anzeigen

```bash
# Alle Ressourcen-Typen
kubectl api-resources

# Pods anzeigen (alle Namespaces)
kubectl get pods -A

# Pods in einem Namespace
kubectl get pods -n <namespace>

# Services anzeigen
kubectl get svc -A

# Deployments anzeigen
kubectl get deployments -A
```

## Pods verstehen

### Was ist ein Pod?

Ein Pod ist die kleinste Einheit in Kubernetes:
- Ein oder mehrere Container
- Geteilter Netzwerk-Namespace
- Geteilter Storage
- Lebenszyklus: Wird erstellt, läuft, wird gelöscht

### Pods anzeigen

```bash
# Alle Pods
kubectl get pods

# Mit mehr Details
kubectl get pods -o wide

# In einem Namespace
kubectl get pods -n kube-system

# Alle Namespaces
kubectl get pods -A
```

### Pod-Details

```bash
# Detaillierte Pod-Info
kubectl describe pod <pod-name>

# Pod-Logs
kubectl logs <pod-name>

# Logs mit Follow (wie tail -f)
kubectl logs -f <pod-name>

# Logs eines Containers in Multi-Container-Pod
kubectl logs <pod-name> -c <container-name>
```

### Pod erstellen (Beispiel)

```bash
# Einfacher Pod
kubectl run nginx-pod --image=nginx

# Pod mit spezifischem Namespace
kubectl run nginx-pod --image=nginx -n default

# Pod löschen
kubectl delete pod nginx-pod
```

## Namespaces verstehen

### Was ist ein Namespace?

Namespaces teilen einen Cluster in logische Bereiche:
- Isolation von Ressourcen
- Organisatorische Trennung
- Zugriffskontrolle (später)

### Namespaces anzeigen

```bash
# Alle Namespaces
kubectl get namespaces
# oder kurz
kubectl get ns

# Standard-Namespaces:
# - default: Deine Anwendungen
# - kube-system: System-Komponenten
# - kube-public: Öffentliche Ressourcen
# - kube-node-lease: Node-Leases
```

### Namespace erstellen

```bash
# Namespace erstellen
kubectl create namespace my-app

# Ressource in Namespace erstellen
kubectl run nginx --image=nginx -n my-app

# Ressourcen in Namespace anzeigen
kubectl get pods -n my-app
```

## Deployments verstehen

### Was ist ein Deployment?

Ein Deployment verwaltet Pods:
- Erstellt und verwaltet Pods
- Skalierung (mehr/weniger Pods)
- Rollouts und Rollbacks
- Selbstheilung (startet Pods neu bei Fehlern)

### Deployment erstellen

```bash
# Deployment erstellen
kubectl create deployment nginx-deployment --image=nginx

# Deployment anzeigen
kubectl get deployments

# Pods des Deployments
kubectl get pods -l app=nginx-deployment
```

### Deployment skalieren

```bash
# Auf 3 Replicas skalieren
kubectl scale deployment nginx-deployment --replicas=3

# Aktuelle Replicas prüfen
kubectl get deployment nginx-deployment
```

### Deployment aktualisieren

```bash
# Image aktualisieren
kubectl set image deployment nginx-deployment nginx=nginx:1.21

# Rollout-Status prüfen
kubectl rollout status deployment nginx-deployment

# Rollout-Historie
kubectl rollout history deployment nginx-deployment

# Rollback
kubectl rollout undo deployment nginx-deployment
```

## Services verstehen

### Was ist ein Service?

Ein Service stellt eine stabile Netzwerk-Adresse für Pods bereit:
- Load Balancing zwischen Pods
- Service Discovery
- Stabile IP-Adresse (auch wenn Pods neu starten)

### Service-Typen

- **ClusterIP**: Interne IP (Standard)
- **NodePort**: Port auf jedem Node
- **LoadBalancer**: Externe IP (Cloud)
- **ExternalName**: Externer DNS-Name

### Service erstellen

```bash
# Service für Deployment
kubectl expose deployment nginx-deployment --port=80 --type=ClusterIP

# Services anzeigen
kubectl get svc

# Service-Details
kubectl describe svc nginx-deployment
```

## Praktische Beispiele

### Beispiel 1: Einfache Web-App

```bash
# Deployment erstellen
kubectl create deployment web-app --image=nginx

# Service erstellen
kubectl expose deployment web-app --port=80 --type=NodePort

# NodePort finden
kubectl get svc web-app

# Zugriff testen (von einem Node aus)
curl http://<node-ip>:<nodeport>
```

### Beispiel 2: Multi-Container Pod

```yaml
# multi-container-pod.yaml (Beispiel-Struktur)
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
  - name: nginx
    image: nginx
  - name: sidecar
    image: busybox
    command: ['sleep', '3600']
```

```bash
# Pod aus YAML erstellen
kubectl apply -f multi-container-pod.yaml

# Logs von spezifischem Container
kubectl logs multi-container-pod -c nginx
```

### Beispiel 3: ConfigMap und Secrets

```bash
# ConfigMap erstellen
kubectl create configmap my-config --from-literal=key1=value1

# ConfigMap anzeigen
kubectl get configmap my-config
kubectl describe configmap my-config

# Secret erstellen
kubectl create secret generic my-secret --from-literal=password=secret123

# Secret anzeigen (Werte sind base64-encoded)
kubectl get secret my-secret -o yaml
```

## YAML-Dateien verwenden

### Ressource aus YAML erstellen

```bash
# YAML anwenden
kubectl apply -f deployment.yaml

# Mehrere Dateien
kubectl apply -f deployment.yaml -f service.yaml

# Alle YAMLs in Verzeichnis
kubectl apply -f k8s/
```

### YAML von bestehender Ressource

```bash
# YAML exportieren
kubectl get deployment nginx-deployment -o yaml > deployment.yaml

# YAML bearbeiten und anwenden
kubectl apply -f deployment.yaml
```

## Debugging-Techniken

### Pod-Status prüfen

```bash
# Pod-Status
kubectl get pods

# Mögliche Status:
# - Pending: Wird erstellt
# - Running: Läuft
# - Succeeded: Erfolgreich beendet
# - Failed: Fehler
# - CrashLoopBackOff: Startet immer wieder neu
```

### Fehlerhafte Pods debuggen

```bash
# Pod-Details
kubectl describe pod <pod-name>

# Pod-Logs
kubectl logs <pod-name>

# In Pod einsteigen (falls möglich)
kubectl exec -it <pod-name> -- /bin/sh
```

### Events anzeigen

```bash
# Alle Events
kubectl get events

# Events für spezifische Ressource
kubectl describe pod <pod-name>  # Zeigt Events am Ende
```

## Nützliche Aliase und Shortcuts

### kubectl Aliase (optional)

Füge zu `~/.bashrc` oder `~/.zshrc` hinzu:

```bash
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ka='kubectl apply'
alias kdel='kubectl delete'
```

### kubectl Shortcuts

```bash
# Statt "pods" kannst du "po" verwenden
kubectl get po

# Statt "services" kannst du "svc" verwenden
kubectl get svc

# Statt "deployments" kannst du "deploy" verwenden
kubectl get deploy
```

## Best Practices

### 1. Immer Namespaces verwenden

```bash
# Explizit Namespace angeben
kubectl get pods -n my-app

# Oder Context mit Namespace setzen
kubectl config set-context --current --namespace=my-app
```

### 2. YAML-Dateien versionieren

- Nutze Git für deine Kubernetes-Manifeste
- Dokumentiere Änderungen
- Teste in Dev vor Prod

### 3. Ressourcen benennen

- Verwende aussagekräftige Namen
- Folge Naming-Conventions
- Nutze Labels für Organisation

## Übungen

### Übung 1: Erstelle eine einfache App

1. Erstelle ein Deployment mit 3 Replicas
2. Exponiere es als Service
3. Skaliere auf 5 Replicas
4. Aktualisiere das Image

### Übung 2: Debugging

1. Erstelle einen Pod mit fehlerhaftem Image
2. Debugge das Problem mit `describe` und `logs`
3. Fixe das Problem

## Checkliste

Du solltest jetzt verstehen:
- [ ] Wie kubectl funktioniert
- [ ] Grundlegende Befehle (get, describe, logs)
- [ ] Was Pods, Deployments, Services sind
- [ ] Wie Namespaces funktionieren
- [ ] Wie du YAML-Dateien verwendest
- [ ] Grundlegende Debugging-Techniken

## Nächste Schritte

Jetzt, da du kubectl beherrschst, geht es weiter mit [Kapitel 8: OpenTofu Einführung](08-opentofu-introduction.md), wo du lernst, wie du deine Infrastruktur als Code verwaltest.

## Weiterführende Ressourcen

- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [kubectl Dokumentation](https://kubernetes.io/docs/reference/kubectl/)
- [Kubernetes Concepts](https://kubernetes.io/docs/concepts/)
- [k9s - Terminal UI](https://k9scli.io/) (optional, aber nützlich)

