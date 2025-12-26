# Kapitel 14: Troubleshooting

## Übersicht

In diesem Kapitel lernst du, wie du häufige Probleme in deinem Kubernetes-Cluster identifizierst und löst. Du wirst Debugging-Techniken und Lösungen für typische Probleme kennenlernen.

## Debugging-Strategien

### Systematischer Ansatz

1. **Problem identifizieren**: Was funktioniert nicht?
2. **Symptome sammeln**: Logs, Events, Status
3. **Ursache finden**: Root Cause Analysis
4. **Lösung anwenden**: Fix implementieren
5. **Verifizieren**: Problem behoben?

### Debugging-Tools

```bash
# kubectl Befehle
kubectl get <resource>
kubectl describe <resource>
kubectl logs <pod>
kubectl exec -it <pod> -- /bin/sh

# System-Befehle (auf Nodes)
journalctl -u k3s
systemctl status k3s
ip addr show
```

## Häufige Probleme

### Problem 1: Pod startet nicht

#### Symptome

```bash
kubectl get pods
# NAME           READY   STATUS
# my-pod         0/1     Pending
# oder
# my-pod         0/1     CrashLoopBackOff
```

#### Debugging

```bash
# Pod-Details
kubectl describe pod <pod-name>

# Pod-Logs
kubectl logs <pod-name>

# Events
kubectl get events --field-selector involvedObject.name=<pod-name>
```

#### Häufige Ursachen

1. **Image nicht gefunden**
   ```
   Error: ImagePullBackOff
   ```
   **Lösung**: Image-Name prüfen, Registry-Zugriff prüfen

2. **Nicht genug Ressourcen**
   ```
   Status: Pending
   Reason: Insufficient resources
   ```
   **Lösung**: Resource Requests/Limits anpassen oder Node hinzufügen

3. **PVC nicht verfügbar**
   ```
   Status: Pending
   Reason: Waiting for volume
   ```
   **Lösung**: PVC-Status prüfen, Storage Class prüfen

4. **Container-Crash**
   ```
   Status: CrashLoopBackOff
   ```
   **Lösung**: Logs prüfen, Container-Konfiguration prüfen

#### Lösungsschritte

```bash
# 1. Pod-Details prüfen
kubectl describe pod <pod-name>

# 2. Logs prüfen
kubectl logs <pod-name>

# 3. In Pod einsteigen (falls möglich)
kubectl exec -it <pod-name> -- /bin/sh

# 4. Events prüfen
kubectl get events --sort-by='.lastTimestamp'
```

### Problem 2: Node zeigt "NotReady"

#### Symptome

```bash
kubectl get nodes
# NAME           STATUS     ROLES
# k3s-worker-1   NotReady  <none>
```

#### Debugging

```bash
# Node-Details
kubectl describe node <node-name>

# Auf Node: K3S Agent Status
ssh kairos@<node-ip>
sudo systemctl status k3s-agent

# K3S Agent Logs
sudo journalctl -u k3s-agent -n 50
```

#### Häufige Ursachen

1. **K3S Agent läuft nicht**
   ```bash
   # Lösung
   sudo systemctl start k3s-agent
   sudo systemctl enable k3s-agent
   ```

2. **Master nicht erreichbar**
   ```bash
   # Test Verbindung
   ping 10.10.10.10  # Master IP
   telnet 10.10.10.10 6443  # API Server Port
   ```

3. **Falscher Token**
   ```bash
   # Token vom Master holen
   ssh kairos@k3s-master
   sudo cat /var/lib/rancher/k3s/server/node-token
   
   # Worker neu installieren mit korrektem Token
   ```

4. **Netzwerk-Problem**
   ```bash
   # Netzwerk-Interface prüfen
   ip addr show
   ip route show
   ```

#### Lösungsschritte

```bash
# 1. K3S Agent Status prüfen
sudo systemctl status k3s-agent

# 2. Logs prüfen
sudo journalctl -u k3s-agent -f

# 3. Netzwerk-Verbindung testen
ping <master-ip>
telnet <master-ip> 6443

# 4. K3S Agent neu starten
sudo systemctl restart k3s-agent
```

### Problem 3: Service nicht erreichbar

#### Symptome

```bash
# Service existiert, aber nicht erreichbar
kubectl get svc
# NAME      TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)
# my-svc    ClusterIP   10.43.x.x    <none>        80/TCP

# Pod kann Service nicht erreichen
```

#### Debugging

```bash
# Service-Details
kubectl describe svc <service-name>

# Endpoints prüfen
kubectl get endpoints <service-name>

# DNS-Test
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <service-name>
```

#### Häufige Ursachen

1. **Keine Endpoints**
   ```
   ENDPOINTS: <none>
   ```
   **Lösung**: Pods existieren? Selector korrekt?

2. **Falscher Selector**
   ```yaml
   # Service Selector muss zu Pod Labels passen
   spec:
     selector:
       app: my-app  # Muss zu Pod Labels passen
   ```

3. **Port falsch**
   ```yaml
   # Service Port muss zu Container Port passen
   spec:
     ports:
     - port: 80
       targetPort: 8080  # Container Port
   ```

#### Lösungsschritte

```bash
# 1. Service-Details prüfen
kubectl describe svc <service-name>

# 2. Endpoints prüfen
kubectl get endpoints <service-name>

# 3. Pod Labels prüfen
kubectl get pods --show-labels

# 4. DNS-Test
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <service-name>
```

### Problem 4: PVC bleibt "Pending"

#### Symptome

```bash
kubectl get pvc
# NAME      STATUS    VOLUME   CAPACITY
# my-pvc    Pending   <none>   <none>
```

#### Debugging

```bash
# PVC-Details
kubectl describe pvc <pvc-name>

# Storage Class prüfen
kubectl get storageclass

# Provisioner Pod prüfen
kubectl get pods -n kube-system | grep nfs
```

#### Häufige Ursachen

1. **Storage Class existiert nicht**
   ```bash
   # Lösung: Storage Class erstellen
   kubectl get storageclass
   ```

2. **NFS Server nicht erreichbar**
   ```bash
   # Test NFS-Verbindung
   showmount -e <nfs-server-ip>
   ```

3. **Provisioner läuft nicht**
   ```bash
   # Provisioner Pod Status
   kubectl get pods -n kube-system | grep nfs
   
   # Provisioner Logs
   kubectl logs -n kube-system -l app=nfs-subdir-external-provisioner
   ```

#### Lösungsschritte

```bash
# 1. PVC-Details prüfen
kubectl describe pvc <pvc-name>

# 2. Storage Class prüfen
kubectl get storageclass

# 3. NFS Server erreichbar?
showmount -e <nfs-server-ip>

# 4. Provisioner Status
kubectl get pods -n kube-system | grep nfs
kubectl logs -n kube-system -l app=nfs-subdir-external-provisioner
```

### Problem 5: K3S Master startet nicht

#### Symptome

```bash
# Auf Master Node
sudo systemctl status k3s
# Status: failed
```

#### Debugging

```bash
# K3S Logs
sudo journalctl -u k3s -n 100

# Port bereits belegt?
sudo netstat -tulpn | grep 6443

# Disk Space?
df -h
```

#### Häufige Ursachen

1. **Port bereits belegt**
   ```bash
   # Lösung: Prozess beenden oder Port ändern
   sudo lsof -i :6443
   ```

2. **Nicht genug RAM**
   ```bash
   # Lösung: RAM prüfen, andere Prozesse beenden
   free -h
   ```

3. **Disk voll**
   ```bash
   # Lösung: Platz schaffen
   df -h
   ```

4. **Berechtigungen**
   ```bash
   # Lösung: Berechtigungen prüfen
   ls -la /var/lib/rancher/k3s/
   ```

#### Lösungsschritte

```bash
# 1. Logs prüfen
sudo journalctl -u k3s -n 100

# 2. Port prüfen
sudo netstat -tulpn | grep 6443

# 3. Ressourcen prüfen
free -h
df -h

# 4. K3S neu installieren (falls nötig)
sudo /usr/local/bin/k3s-uninstall.sh
curl -sfL https://get.k3s.io | sh -
```

## Debugging-Techniken

### Log-Analyse

```bash
# Pod-Logs mit Timestamps
kubectl logs <pod-name> --timestamps

# Logs der letzten 100 Zeilen
kubectl logs <pod-name> --tail=100

# Logs seit bestimmter Zeit
kubectl logs <pod-name> --since=1h

# Logs von allen Containers
kubectl logs <pod-name> --all-containers=true
```

### Event-Analyse

```bash
# Alle Events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Events für spezifische Resource
kubectl describe pod <pod-name>  # Zeigt Events am Ende

# Events filtern
kubectl get events --field-selector type=Warning
```

### Netzwerk-Debugging

```bash
# DNS-Test
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Netzwerk-Verbindung testen
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://<service-name>

# Port-Test
kubectl run -it --rm debug --image=busybox --restart=Never -- nc -zv <host> <port>
```

### Container-Debugging

```bash
# In laufenden Container einsteigen
kubectl exec -it <pod-name> -- /bin/sh

# Debug-Container im gleichen Pod
kubectl debug <pod-name> -it --image=busybox --target=<container-name>

# Ephemeral Container (Kubernetes 1.23+)
kubectl debug -it <pod-name> --image=busybox --share-processes
```

## Häufige Fehlermeldungen

### ImagePullBackOff

**Ursache**: Image kann nicht heruntergeladen werden

**Lösung**:
```bash
# Image-Name prüfen
kubectl describe pod <pod-name>

# Registry-Zugriff prüfen
docker pull <image-name>

# Image Pull Secrets prüfen (falls private Registry)
kubectl get secrets
```

### CrashLoopBackOff

**Ursache**: Container startet, crasht sofort, wird neu gestartet

**Lösung**:
```bash
# Logs prüfen
kubectl logs <pod-name> --previous

# Container-Konfiguration prüfen
kubectl describe pod <pod-name>

# In Container einsteigen (falls möglich)
kubectl exec -it <pod-name> -- /bin/sh
```

### ErrImagePull

**Ursache**: Image kann nicht heruntergeladen werden

**Lösung**:
```bash
# Image-Name und Tag prüfen
# Registry erreichbar?
# Credentials korrekt?
```

### OOMKilled

**Ursache**: Out of Memory - Container wurde wegen zu viel RAM beendet

**Lösung**:
```bash
# Memory Limits erhöhen
# Oder weniger Ressourcen-intensive Image verwenden
```

## Nützliche Befehle

### Cluster-Status prüfen

```bash
# Vollständiger Cluster-Status
kubectl get all -A

# Nodes
kubectl get nodes -o wide

# System Pods
kubectl get pods -n kube-system

# Events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### Ressourcen prüfen

```bash
# Ressourcen-Verbrauch
kubectl top nodes
kubectl top pods

# Resource Quotas
kubectl get resourcequota -A

# Limits
kubectl describe node <node-name> | grep -A 10 "Allocated resources"
```

### Cleanup

```bash
# Fehlerhafte Pods löschen
kubectl delete pod <pod-name> --force --grace-period=0

# Alle Pods in Namespace löschen
kubectl delete pods --all -n <namespace>

# Evicted Pods löschen
kubectl get pods --all-namespaces | grep Evicted | awk '{print $1, $2}' | xargs -n2 kubectl delete pod -n
```

## Community-Ressourcen

### Dokumentation

- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)
- [K3S Troubleshooting](https://docs.k3s.io/troubleshooting)
- [Kubernetes Debugging](https://kubernetes.io/docs/tasks/debug-application-cluster/)

### Foren und Communities

- [Kubernetes Slack](https://slack.k8s.io/)
- [K3S GitHub Discussions](https://github.com/k3s-io/k3s/discussions)
- [Reddit r/kubernetes](https://www.reddit.com/r/kubernetes/)

### Tools

- **k9s**: Terminal UI für Kubernetes
- **Lens**: Desktop UI für Kubernetes
- **kubectx/kubens**: Context und Namespace wechseln

## Checkliste für Troubleshooting

Wenn etwas nicht funktioniert:

- [ ] Cluster-Status prüfen (`kubectl get nodes`)
- [ ] Pod-Status prüfen (`kubectl get pods -A`)
- [ ] Logs prüfen (`kubectl logs <pod>`)
- [ ] Events prüfen (`kubectl get events`)
- [ ] Resource-Details prüfen (`kubectl describe <resource>`)
- [ ] Netzwerk-Verbindung testen
- [ ] Dokumentation konsultieren
- [ ] Community um Hilfe bitten (falls nötig)

## Zusammenfassung

Du hast jetzt gelernt:
- Systematische Debugging-Strategien
- Häufige Probleme und Lösungen
- Debugging-Techniken und Tools
- Nützliche Befehle für Troubleshooting
- Wo du Hilfe findest

## Weiterführende Ressourcen

- [Kubernetes Debugging Guide](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [K3S Troubleshooting](https://docs.k3s.io/troubleshooting)
- [Kubernetes Common Issues](https://kubernetes.io/docs/setup/best-practices/)
- [k9s Documentation](https://k9scli.io/)

---

**Glückwunsch!** Du hast den vollständigen Guide durchgearbeitet. Du solltest jetzt in der Lage sein, deinen Kubernetes-Cluster aufzubauen, zu konfigurieren und zu betreiben. Viel Erfolg mit deinem Homelab-Cluster!

