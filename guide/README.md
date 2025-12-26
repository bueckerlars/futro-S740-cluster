# Kubernetes Homelab Cluster Guide

Willkommen zum vollständigen Guide für den Aufbau eines K3S-Kubernetes-Clusters im Homelab! Dieser Guide führt dich Schritt für Schritt durch die Planung, Installation und Konfiguration deines Clusters.

## Über diesen Guide

Dieser Guide ist speziell für Anfänger konzipiert, die noch keine Erfahrung mit Kubernetes haben. Jedes Kapitel baut auf den vorherigen auf und erklärt nicht nur das "Wie", sondern auch das "Warum". Du wirst lernen, wie du deinen Cluster selbst konfigurierst, anstatt nur vorgefertigte Konfigurationen zu kopieren.

### Zielsetzung

Am Ende dieses Guides wirst du:
- Einen funktionierenden K3S-Kubernetes-Cluster mit 1 Master und 3 Worker Nodes haben
- Verstehen, wie Kubernetes funktioniert und wie du es nutzt
- Deine Infrastruktur mit OpenTofu, Ansible und Helm verwalten können
- Best Practices für Homelab-Cluster kennen und anwenden

### Hardware-Setup

- **4x Fujitsu Futro S740** (1 Master, 3 Worker)
- **Managed 8 Port Gbit Switch**
- **VLAN**: 10.10.X.X IP-Range
- **Storage**: NFS Share auf vorhandenem NAS

### Software-Stack

- **Kairos** (Alpine-based) - Minimales, immutables OS
- **K3S** - Lightweight Kubernetes Distribution
- **OpenTofu** - Infrastructure as Code
- **Ansible** - Configuration Management
- **Helm** - Kubernetes Package Manager

## Inhaltsverzeichnis

### Phase 1: Grundlagen & Vorbereitung

1. **[Einführung](01-introduction.md)** - Was ist Kubernetes? Architektur und Konzepte
2. **[Voraussetzungen](02-prerequisites.md)** - Hardware-Checkliste und Planung
3. **[Netzwerk-Setup](03-network-setup.md)** - VLAN-Konfiguration und IP-Allokation

### Phase 2: Installation

4. **[Kairos Installation](04-kairos-installation.md)** - OS Installation auf allen Nodes
5. **[K3S Master Setup](05-k3s-master-setup.md)** - Master Node Installation
6. **[K3S Worker Setup](06-k3s-worker-setup.md)** - Worker Nodes Installation

### Phase 3: Grundlagen & Tools

7. **[kubectl Grundlagen](07-kubectl-basics.md)** - Kubernetes CLI verstehen und nutzen
8. **[OpenTofu Einführung](08-opentofu-introduction.md)** - Infrastructure as Code Grundlagen
9. **[Ansible Einführung](09-ansible-introduction.md)** - Configuration Management Grundlagen
10. **[Helm Einführung](10-helm-introduction.md)** - Kubernetes Package Manager

### Phase 4: Erweiterte Konfiguration

11. **[IaC für Cluster-Management](11-iac-cluster-management.md)** - Integration aller Tools
12. **[Storage (NFS)](12-storage-nfs.md)** - Persistent Storage einrichten

### Phase 5: Wartung & Best Practices

13. **[Best Practices](13-best-practices.md)** - Security, Monitoring, Backups
14. **[Troubleshooting](14-troubleshooting.md)** - Häufige Probleme und Lösungen

## Wie du diesen Guide nutzt

1. **Arbeite die Kapitel der Reihe nach durch** - Jedes Kapitel baut auf den vorherigen auf
2. **Nimm dir Zeit** - Kubernetes ist komplex, es ist normal, dass du Zeit brauchst
3. **Experimentiere** - Probiere die Beispiele aus und verändere sie
4. **Dokumentiere deine Konfiguration** - Notiere dir deine spezifischen Einstellungen
5. **Nutze die Querverweise** - Springe zwischen verwandten Themen hin und her

## Voraussetzungen

Bevor du startest, solltest du:
- Grundkenntnisse in Linux/CLI haben (intermediate level)
- Zugriff auf deine Hardware haben
- Einen Managed Switch mit VLAN-Unterstützung haben
- Einen NFS-Server im Netzwerk haben (bereits vorhanden)

## Nächste Schritte

Beginne mit [Kapitel 1: Einführung](01-introduction.md) um die Grundlagen von Kubernetes und die Architektur deines zukünftigen Clusters zu verstehen.

---

**Hinweis**: Dieser Guide ist für Homelab-Umgebungen optimiert. Für Produktionsumgebungen gelten andere Anforderungen und Best Practices.

