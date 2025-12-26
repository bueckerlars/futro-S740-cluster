# Kapitel 9: Ansible Einführung

## Übersicht

In diesem Kapitel lernst du Ansible kennen, ein Tool für Configuration Management und Automatisierung. Du wirst verstehen, wie du System-Konfiguration und K3S-Installation automatisiert.

## Was ist Ansible?

Ansible ist ein Open-Source-Tool für:
- **Configuration Management**: Systeme konsistent konfigurieren
- **Automation**: Wiederholbare Tasks automatisieren
- **Orchestration**: Mehrere Systeme koordiniert verwalten

### Warum Ansible?

- **Agentless**: Keine Software auf Ziel-Systemen nötig (nur SSH)
- **Einfach**: YAML-basierte Konfiguration
- **Idempotent**: Mehrfaches Ausführen ist sicher
- **Python-basiert**: Erweiterbar mit Python

### Ansible vs. andere Tools

| Feature | Ansible | Puppet | Chef |
|---------|---------|--------|------|
| Agent | Nein | Ja | Ja |
| Sprache | YAML | Ruby DSL | Ruby DSL |
| Lernkurve | Niedrig | Mittel | Mittel |

## Installation

### Linux

```bash
# Über pip (empfohlen)
pip install ansible

# Oder über Package Manager
sudo apt install ansible  # Debian/Ubuntu
sudo yum install ansible  # RHEL/CentOS
```

### Mac

```bash
brew install ansible
```

### Windows

Ansible läuft nicht nativ auf Windows. Verwende:
- WSL (Windows Subsystem for Linux)
- Oder Linux-VM

### Verifikation

```bash
ansible --version
# Sollte Version anzeigen
```

## Grundlegende Konzepte

### Inventory

Ein Inventory listet die Systeme, die du verwalten willst.

**Beispiel** (`inventory.ini`):
```ini
[master]
k3s-master ansible_host=10.10.10.10 ansible_user=kairos

[workers]
k3s-worker-1 ansible_host=10.10.10.11 ansible_user=kairos
k3s-worker-2 ansible_host=10.10.10.12 ansible_user=kairos
k3s-worker-3 ansible_host=10.10.10.13 ansible_user=kairos

[k3s_cluster:children]
master
workers
```

### Playbooks

Playbooks sind YAML-Dateien, die Tasks definieren.

**Beispiel** (`playbook.yml`):
```yaml
---
- name: Update system packages
  hosts: k3s_cluster
  become: yes
  tasks:
    - name: Update package cache
      apk:
        update_cache: yes
```

### Tasks

Tasks sind einzelne Aktionen, die ausgeführt werden.

**Beispiel**:
```yaml
- name: Install package
  apk:
    name: curl
    state: present
```

### Modules

Modules sind vorgefertigte Funktionen für spezifische Tasks.

**Beispiele**:
- `apt`/`apk`: Paket-Management
- `copy`: Dateien kopieren
- `template`: Templates rendern
- `service`: Services verwalten
- `command`: Befehle ausführen

## Erste Schritte

### Projekt-Struktur

```bash
mkdir -p ~/cluster-iac/ansible
cd ~/cluster-iac/ansible

# Erstelle Struktur
mkdir -p group_vars host_vars roles
```

### Inventory erstellen

Erstelle `inventory.ini`:

```ini
[master]
k3s-master ansible_host=10.10.10.10 ansible_user=kairos

[workers]
k3s-worker-1 ansible_host=10.10.10.11 ansible_user=kairos
k3s-worker-2 ansible_host=10.10.10.12 ansible_user=kairos
k3s-worker-3 ansible_host=10.10.10.13 ansible_user=kairos

[k3s_cluster:children]
master
workers
```

### SSH-Zugriff testen

```bash
# Test Verbindung zu allen Hosts
ansible all -i inventory.ini -m ping

# Sollte für alle Hosts "SUCCESS" zeigen
```

### Erste Playbook

Erstelle `playbook.yml`:

```yaml
---
- name: Basic system setup
  hosts: k3s_cluster
  become: yes
  tasks:
    - name: Update package cache
      apk:
        update_cache: yes

    - name: Install basic packages
      apk:
        name:
          - curl
          - wget
          - vim
        state: present
```

### Playbook ausführen

```bash
# Dry-run (zeigt, was gemacht würde)
ansible-playbook -i inventory.ini playbook.yml --check

# Ausführen
ansible-playbook -i inventory.ini playbook.yml
```

## K3S Installation mit Ansible

### Master Node Installation

Erstelle `playbooks/k3s-master.yml`:

```yaml
---
- name: Install K3S Master
  hosts: master
  become: yes
  vars:
    k3s_version: "latest"
  tasks:
    - name: Install K3S
      shell: |
        curl -sfL https://get.k3s.io | sh -
      creates: /usr/local/bin/k3s

    - name: Wait for K3S to be ready
      wait_for:
        port: 6443
        host: "{{ ansible_host }}"
        delay: 10
        timeout: 300

    - name: Get K3S token
      shell: cat /var/lib/rancher/k3s/server/node-token
      register: k3s_token
      changed_when: false

    - name: Display token
      debug:
        msg: "K3S Token: {{ k3s_token.stdout }}"
```

### Worker Node Installation

Erstelle `playbooks/k3s-workers.yml`:

```yaml
---
- name: Install K3S Workers
  hosts: workers
  become: yes
  vars:
    k3s_master_ip: "10.10.10.10"
    k3s_token: "{{ hostvars['k3s-master']['k3s_token'] | default('') }}"
  tasks:
    - name: Fail if token not set
      fail:
        msg: "K3S token must be set. Run master playbook first."
      when: k3s_token == ""

    - name: Install K3S Agent
      shell: |
        curl -sfL https://get.k3s.io | K3S_URL=https://{{ k3s_master_ip }}:6443 K3S_TOKEN={{ k3s_token }} sh -
      creates: /usr/local/bin/k3s

    - name: Wait for agent to be ready
      wait_for:
        path: /var/lib/rancher/k3s/agent/etc/kubelet.yaml
        timeout: 300
```

### Variablen in group_vars

Erstelle `group_vars/all.yml`:

```yaml
---
# Cluster configuration
cluster_name: futro-cluster
vlan_subnet: "10.10.10.0/24"
gateway: "10.10.10.1"

# K3S configuration
k3s_master_ip: "10.10.10.10"
k3s_version: "latest"

# NFS configuration
nfs_server: "10.10.10.20"
nfs_path: "/mnt/storage/k3s"
```

### Master-spezifische Variablen

Erstelle `group_vars/master.yml`:

```yaml
---
k3s_role: master
```

### Worker-spezifische Variablen

Erstelle `group_vars/workers.yml`:

```yaml
---
k3s_role: worker
```

## Erweiterte Konzepte

### Roles

Roles organisieren Playbooks in wiederverwendbare Komponenten.

**Struktur**:
```
roles/
  k3s/
    tasks/
      main.yml
    vars/
      main.yml
    templates/
      config.yaml.j2
```

**Beispiel Role** (`roles/k3s/tasks/main.yml`):
```yaml
---
- name: Install K3S
  include_tasks: install.yml
  when: k3s_role == "master"

- name: Install K3S Agent
  include_tasks: install-agent.yml
  when: k3s_role == "worker"
```

### Templates

Templates erlauben dynamische Konfigurations-Dateien.

**Beispiel** (`templates/k3s-config.yaml.j2`):
```yaml
# K3S Configuration
cluster-cidr: "{{ cluster_cidr }}"
service-cidr: "{{ service_cidr }}"
cluster-dns: "{{ cluster_dns }}"
```

**Verwendung**:
```yaml
- name: Copy K3S config
  template:
    src: k3s-config.yaml.j2
    dest: /etc/rancher/k3s/config.yaml
```

### Handlers

Handlers sind Tasks, die nur ausgeführt werden, wenn sie getriggert werden.

**Beispiel**:
```yaml
tasks:
  - name: Update config file
    template:
      src: config.yaml.j2
      dest: /etc/config.yaml
    notify: restart service

handlers:
  - name: restart service
    systemd:
      name: k3s
      state: restarted
```

## Praktische Beispiele

### Beispiel 1: System-Updates

```yaml
---
- name: Update all nodes
  hosts: k3s_cluster
  become: yes
  tasks:
    - name: Update package cache
      apk:
        update_cache: yes

    - name: Upgrade all packages
      apk:
        upgrade: dist
```

### Beispiel 2: Dateien kopieren

```yaml
---
- name: Copy files to nodes
  hosts: k3s_cluster
  become: yes
  tasks:
    - name: Copy SSH keys
      copy:
        src: ~/.ssh/id_rsa.pub
        dest: /home/kairos/.ssh/authorized_keys
        mode: '0600'
        owner: kairos
        group: kairos
```

### Beispiel 3: Services verwalten

```yaml
---
- name: Manage services
  hosts: k3s_cluster
  become: yes
  tasks:
    - name: Ensure SSH is running
      systemd:
        name: sshd
        state: started
        enabled: yes
```

## Best Practices

### 1. Idempotenz

Stelle sicher, dass Tasks idempotent sind (mehrfaches Ausführen ist sicher):

```yaml
# Gut: Idempotent
- name: Install package
  apk:
    name: curl
    state: present

# Schlecht: Nicht idempotent
- name: Install package
  command: apk add curl
```

### 2. Variablen verwenden

```yaml
# Gut: Variablen
- name: Install K3S
  shell: curl -sfL https://get.k3s.io | sh -
  vars:
    k3s_version: "{{ k3s_version | default('latest') }}"

# Schlecht: Hardcoded
- name: Install K3S
  shell: curl -sfL https://get.k3s.io | sh -
```

### 3. Fehlerbehandlung

```yaml
- name: Risky task
  command: some-command
  ignore_errors: yes
  register: result

- name: Check result
  fail:
    msg: "Task failed"
  when: result.rc != 0
```

### 4. Dokumentation

```yaml
---
- name: Install K3S Master
  hosts: master
  become: yes
  # Kommentare für Klarheit
  vars:
    k3s_version: "latest"  # K3S Version
  tasks:
    - name: Install K3S
      # Installiert K3S Master Node
      shell: curl -sfL https://get.k3s.io | sh -
```

## Für deinen Cluster

### Typischer Workflow

1. **Basis-Setup**: System-Updates, Pakete installieren
2. **K3S Master**: Master Node installieren
3. **K3S Workers**: Worker Nodes installieren
4. **Konfiguration**: Cluster-Konfiguration anwenden
5. **Verifikation**: Cluster-Status prüfen

### Beispiel: Vollständiges Setup

```yaml
---
# playbooks/setup-cluster.yml
- name: Setup K3S Cluster
  hosts: localhost
  gather_facts: no
  tasks:
    - name: Install Master
      include: k3s-master.yml

    - name: Get token from master
      # Token wird für Workers benötigt

    - name: Install Workers
      include: k3s-workers.yml
```

## Übungen

### Übung 1: Basis-Setup

1. Erstelle ein Inventory mit deinen Nodes
2. Teste SSH-Verbindungen
3. Erstelle ein Playbook für System-Updates
4. Führe es aus

### Übung 2: K3S Installation

1. Erstelle Playbooks für Master und Workers
2. Installiere K3S mit Ansible
3. Verifiziere die Installation

## Checkliste

Du solltest jetzt verstehen:
- [ ] Was Ansible ist und wofür es verwendet wird
- [ ] Grundlegende Konzepte (Inventory, Playbooks, Tasks)
- [ ] Wie du ein Ansible-Projekt erstellst
- [ ] Wie du K3S mit Ansible installierst
- [ ] Best Practices für Ansible

## Nächste Schritte

Jetzt, da du Ansible kennst, geht es weiter mit [Kapitel 10: Helm Einführung](10-helm-introduction.md), wo du lernst, wie du Kubernetes-Anwendungen mit Helm verwaltest.

## Weiterführende Ressourcen

- [Ansible Dokumentation](https://docs.ansible.com/)
- [Ansible Module Index](https://docs.ansible.com/ansible/latest/collections/index.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Ansible Galaxy](https://galaxy.ansible.com/) (Community Roles)

