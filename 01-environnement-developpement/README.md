# Atelier 01 – Environnement de développement Ansible

## Objectifs

- Comprendre les rôles dans l'architecture Ansible
- Mettre en place un environnement local de développement (VSCode + Git)
- Écrire et exécuter un playbook de test en local
- Comprendre les principes de communication entre noeuds Ansible

---

## Concepts fondamentaux

### Control Node

Le **control node** est la machine où Ansible est installé et exécuté. C'est elle qui :
- Interprète les playbooks
- Se connecte aux machines distantes (managed nodes)
- Exécute les modules à distance (via SSH par défaut)

> Dans notre cas, **VSCode et Ansible sont installés sur le control node**.

### Managed Nodes

Ce sont les machines distantes (Linux, Windows, équipements réseau, etc.) sur lesquelles Ansible agit :
- Installation de paquets
- Configuration système
- Déploiement d'applications
- Vérification de conformité

> Ansible n'a **pas besoin d'agent** sur les **managed nodes** (contrairement à Puppet ou SCCM).  
> Il utilise **SSH pour Linux** et **WinRM pour Windows**.

---

## Structure du projet

```bash
01-environnement-developpement/
├── inventory/          # Inventaire Ansible (localhost pour test)
├── project/            # Playbook et configuration locale
└── README.md           # Ce fichier
```

---

## Contenu des fichiers

### `inventory/hosts.ini`

```ini
[local]
localhost ansible_connection=local

[linux]
srv-ansible ansible_host=127.0.0.1 ansible_user=ansible ansible_ssh_private_key_file=~/.ssh/id_rsa

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

Ce fichier décrit deux groupes d’hôtes :

1. **\[local]** : Utilisé pour exécuter des playbooks localement sur le control node sans passer par SSH (`ansible_connection=local`).
2. **\[linux]** : Groupe contenant un serveur Linux appelé `srv-ansible`, accessible en SSH via l’adresse `127.0.0.1` avec l’utilisateur `ansible`.

La section `[all:vars]` définit une variable globale à tous les hôtes : le chemin de l’interpréteur Python utilisé à distance. Cela garantit que les modules Python Ansible s’exécutent correctement sur les managed nodes.

---

### Connexion SSH par échange de clés

Ansible utilise le protocole SSH pour se connecter aux machines distantes. Pour automatiser les connexions, on privilégie l’**authentification par clé publique/privée**, ce qui évite les mots de passe interactifs.

**Fonctionnement :**

* Le **control node** possède une **clé privée** (`~/.ssh/id_rsa`)
* Le **managed node** (serveur distant) possède la **clé publique correspondante** dans son fichier `~/.ssh/authorized_keys`
* Lorsqu'Ansible se connecte en tant qu'utilisateur `ansible`, la correspondance des clés permet une connexion automatique

**Avantages :**

* Sécurité accrue (pas de mot de passe en clair)
* Possibilité d’automatisation (aucune saisie humaine nécessaire)
* Intégration facile avec AWX

**Recommandation pour les participants :**
Chaque élève doit disposer :

* D’une **clé privée SSH** sur son poste (ou sur le control node)
* De la **clé publique installée dans `~ansible/.ssh/authorized_keys`** sur chaque managed node

```bash
# Exemple de génération de clé SSH
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# Exemple de copie de la clé publique vers un managed node
ssh-copy-id -i ~/.ssh/id_rsa.pub ansible@<ip_du_serveur>
```

---

### Utilisateur `ansible` et élévation des privilèges

Sur chaque serveur géré, un utilisateur nommé `ansible` sera utilisé pour les connexions SSH.

Ce compte :

* Est membre du groupe `sudo` (ou `wheel` selon les distributions)
* A le droit d’exécuter des commandes en tant que superutilisateur sans mot de passe

Extrait de fichier `/etc/sudoers.d/ansible` :

```bash
ansible ALL=(ALL) NOPASSWD: ALL
```

Cela permet à Ansible d’exécuter des tâches nécessitant des droits root (comme l’installation de paquets) via le paramètre `become: true` dans les playbooks.

Exemple :

```yaml
- name: Install NGINX
  become: true
  ansible.builtin.package:
    name: nginx
    state: present
```

Cette configuration est essentielle pour une automatisation complète des tâches d’administration système.

### `project/ansible.cfg`

```ini
[defaults]
inventory = ../inventory/hosts.ini
host_key_checking = False
retry_files_enabled = False
```

#### Détail du fichier `ansible.cfg`

| Clé                   | Description                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------------ |
| `inventory`           | Définit le chemin vers le fichier d’inventaire. Ici, il pointe vers `../inventory/hosts.ini`                 |
| `host_key_checking`   | Désactive la vérification de la clé SSH connue dans `~/.ssh/known_hosts`. Pratique en environnement de test. |
| `retry_files_enabled` | Évite la création automatique de fichiers `.retry` en cas d’échec. Cela garde le projet propre.              |

> Ce fichier permet de **personnaliser le comportement d’Ansible** dans un projet sans modifier la configuration globale du système.
---

### `project/playbook_test.yml`

Bien noté, j'éviterai l'usage d'icônes et d'emojis à l’avenir.

Voici la section `### project/playbook_test.yml` réécrite avec une **explication détaillée** du contenu du playbook, claire et pédagogique :

---

### `project/playbook_test.yml`

```yaml
---
- name: Local Ansible test playbook
  hosts: all
  gather_facts: true

  tasks:
    - name: Ping localhost
      ansible.builtin.ping:
      tags: ping

    - name: Show distribution name
      ansible.builtin.debug:
        var: ansible_facts['distribution']
      tags: facts
```

Ce playbook sert à valider que l’environnement Ansible est fonctionnel. Il est exécuté localement sur le control node.

* `name`: Titre général du playbook, affiché lors de l'exécution.
* `hosts: all`: Le playbook cible tous les hôtes définis dans l’inventaire. Ici, il s'agit de `localhost`.
* `gather_facts: true`: Active la collecte automatique des informations système (`facts`) avant l'exécution des tâches.

Le bloc `tasks` contient deux actions :

1. **Ping localhost**
   Utilise le module `ansible.builtin.ping` pour vérifier que la connexion fonctionne. Ce module ne fait qu’envoyer un ping logique (pas ICMP), et vérifie que la communication avec la machine cible est possible.

2. **Show distribution name**
   Affiche le nom de la distribution Linux (ex: Ubuntu, CentOS) récupéré via les facts (`ansible_facts['distribution']`).
   Cela démontre que les facts ont bien été collectés automatiquement.

Chaque tâche est taguée (`tags: ping` et `tags: facts`) afin de pouvoir les exécuter individuellement via la ligne de commande.

Exemples d’exécution sélective :

```bash
ansible-playbook playbook_test.yml --tags ping
ansible-playbook playbook_test.yml --tags facts
```

Ce playbook simple constitue une bonne base pour tester une première connexion et explorer le fonctionnement de base d’Ansible.

---

## Exécution du test

1. Ouvrir VSCode dans ce dossier :

```bash
code 01-environnement-developpement/
```

2. Se placer dans le dossier `project/` :

```bash
cd project
```

3. Lancer le playbook en local :

```bash
ansible-playbook -i ../inventory/host.ini playbook_test.yml --tags ping
ansible-playbook -i .../inventory/host.ini playbook_test.yml --tags facts
```

4. Executer le playbook en selectionnant des taches avec les tags :

- Executer que la tache ping sur les **managed nodes** :

```bash
ansible-playbook -i ../inventory/host.ini playbook_test.yml --tags ping
```

- Executer que la collecte de la distribution linux sur les **managed nodes** :

```bash
ansible-playbook -i ../inventory/host.ini playbook_test.yml --tags facts
```

1. Limiter l'execution d'un playbook sur des **managed nodes** de l'inventaire :

- Limiter uniquement à l'hôte **srv-ansible** :

```bash
ansible-playbook -i ../inventory/host.ini playbook_test.yml -l 'srv-ansible'
```

- Limiter uniquement au groupe **linux** :

```bash
ansible-playbook -i ../inventory/host.ini playbook_test.yml -l 'linux'
```

- Limiter uniquement aux contenant la chaine de caractere **srv** :

```bash
ansible-playbook -i ../inventory/host.ini playbook_test.yml -l 'srv*'
```

Documentation : [Patterns and ad-hoc commands](https://docs.ansible.com/ansible/latest/inventory_guide/intro_patterns.html#patterns-and-ad-hoc-commands)

---

## Pour aller plus loin

* Modifier le playbook pour ajouter une tâche `uptime` avec `ansible.builtin.command`
* Créer une branche Git : `feature/premier-playbook`
* Commit + Push vers GitLab
* Préparer ce répertoire pour être importé dans AWX (project SCM)

---

## Pour approfondir

* Page officielle RedHat :
  👉 [How Ansible works (RedHat)](https://www.redhat.com/en/ansible-collaborative/how-ansible-works)
