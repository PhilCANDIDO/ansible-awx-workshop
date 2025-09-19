# Atelier 03 – Déploiement d'applications Web et Base de données

## 🎯 Objectifs de l'atelier

Dans cet atelier, vous allez apprendre à :
- ✅ Créer des rôles Ansible réutilisables pour déployer des applications
- ✅ Installer et configurer **nginx** comme serveur web
- ✅ Installer et configurer **MySQL** comme base de données
- ✅ Gérer les templates de configuration avec Jinja2
- ✅ Tester la connectivité entre les services
- ✅ Automatiser le déploiement complet d'une stack applicative

---

## 📋 Prérequis

### Environnement requis
- ✅ Une ou plusieurs VMs Linux (créées dans l'atelier 02)
- ✅ Accès SSH avec l'utilisateur `ansible`
- ✅ Connexion Internet pour télécharger les packages
- ✅ Python 3 installé sur les VMs cibles

### Connaissances
- ✅ Bases d'Ansible (atelier 01)
- ✅ Utilisation des rôles Ansible
- ✅ Notions de services Linux (systemd)

---

## 🚀 Installation rapide

### Étape 1 : Préparer l'inventaire

Depuis le vCenter récupérer les adresses IP des VMs **web-server-01** et **db-server-01** précedement créées dans le TP **Déploiement de VM sur VMware avec Ansible**

```bash
cd 03-deploiement-applications/

# Éditer le fichier d'inventaire avec vos VMs web-server-01 et db-server-01
nano inventory/hosts.ini
```

### Étape 2 : Configurer les variables

```bash
# Copier et adapter les variables
cp group_vars/all/main.yml.example group_vars/all/main.yml
nano group_vars/all/main.yml
```

### Étape 3 : Déployer le serveur web

```bash
# Déployer nginx sur les serveurs web
ansible-playbook -i inventory/hosts.ini deploy_webserver.yml
```

### Étape 4 : Déployer la base de données

```bash
# Déployer MySQL sur les serveurs de base de données
ansible-playbook -i inventory/hosts.ini deploy_database.yml
```

### Étape 5 : Déploiement complet de la stack

```bash
# Déployer tout en une seule commande
ansible-playbook -i inventory/hosts.ini deploy_apps.yml
```

---

## 📊 Architecture déployée

```
┌─────────────────────────────────────────────┐
│            Serveur Web (nginx)              │
│                                             │
│  - Port 80 (HTTP)                          │
│  - Port 443 (HTTPS avec certificat auto)   │
│  - Site statique de démonstration          │
│  - Configuration personnalisable            │
└─────────────────────────────────────────────┘
                      ↓
                  Connexion
                      ↓
┌─────────────────────────────────────────────┐
│         Base de données (MySQL)             │
│                                             │
│  - Port 3306                               │
│  - Base de données: app_db                 │
│  - Utilisateur: app_user                   │
│  - Sécurisation automatique                │
└─────────────────────────────────────────────┘
```

---

## 🔧 Variables disponibles

### Variables du serveur web (nginx)

| Variable | Description | Valeur par défaut | Exemple |
|----------|-------------|-------------------|---------|
| `nginx_port` | Port HTTP | `80` | `8080` |
| `nginx_ssl_port` | Port HTTPS | `443` | `8443` |
| `nginx_server_name` | Nom du serveur | `_` | `app.example.com` |
| `nginx_document_root` | Racine web | `/var/www/html` | `/srv/www` |
| `nginx_enable_ssl` | Activer SSL | `true` | `false` |
| `nginx_worker_processes` | Nombre de workers | `auto` | `4` |

### Variables de la base de données (MySQL)

| Variable | Description | Valeur par défaut | Exemple |
|----------|-------------|-------------------|---------|
| `mysql_root_password` | Mot de passe root | `ChangeMe123!` | `SecureP@ss` |
| `mysql_database` | Base par défaut | `app_db` | `production` |
| `mysql_user` | Utilisateur app | `app_user` | `webapp` |
| `mysql_password` | Mot de passe app | `AppPass123!` | `MyAppP@ss` |
| `mysql_port` | Port MySQL | `3306` | `3307` |
| `mysql_bind_address` | Adresse d'écoute | `0.0.0.0` | `127.0.0.1` |

---

## 💻 Exemples d'utilisation

### Exemple 1 : Déploiement simple sur une seule VM

```bash
# Tout sur la même machine (dev/test)
ansible-playbook -i inventory/hosts.ini deploy_apps.yml \
  -e "target_host=vm-test-01"
```

### Exemple 2 : Architecture distribuée

```bash
# Serveur web sur une VM, BDD sur une autre
ansible-playbook -i inventory/hosts.ini deploy_apps.yml \
  -e "web_hosts=web-servers db_hosts=db-servers"
```

### Exemple 3 : Configuration personnalisée

```bash
# Avec des paramètres spécifiques
ansible-playbook -i inventory/hosts.ini deploy_webserver.yml \
  -e "nginx_port=8080 nginx_server_name=myapp.local"

ansible-playbook -i inventory/hosts.ini deploy_database.yml \
  -e "mysql_database=prod_db mysql_user=prod_user"
```

---

## 🧪 Tests de validation

### Test 1 : Vérifier nginx

```bash
# Tester le serveur web
curl -I http://<IP_VM>

# Vérifier le status de nginx
ansible webservers -i inventory/hosts.ini -m systemd -a "name=nginx"
```

### Test 2 : Vérifier MySQL

```bash
# Tester la connexion MySQL
ansible databases -i inventory/hosts.ini -m mysql_info -a "login_user=root login_password=ChangeMe123!"

# Vérifier que la base existe
ansible databases -i inventory/hosts.ini -m mysql_db -a "name=app_db state=present login_user=root login_password=ChangeMe123!"
```

### Test 3 : Test de connectivité complet

```bash
# Lancer le playbook de test
ansible-playbook -i inventory/hosts.ini test_apps.yml
```

---

## 📚 Structure des fichiers du projet

```
03-deploiement-applications/
├── README.md                      # Cette documentation
├── requirements.yml               # Collections Ansible requises
├── deploy_apps.yml               # Playbook principal (déploie tout)
├── deploy_webserver.yml          # Playbook pour nginx seulement
├── deploy_database.yml           # Playbook pour MySQL seulement
├── test_apps.yml                 # Tests de validation
├── inventory/
│   └── hosts.ini                 # Inventaire des serveurs
├── group_vars/
│   └── all/
│       ├── main.yml              # Variables globales
│       └── vault.yml             # Mots de passe (chiffrés)
└── roles/
    ├── webserver/                # Rôle nginx
    │   ├── tasks/main.yml
    │   ├── handlers/main.yml
    │   ├── templates/
    │   │   ├── nginx.conf.j2
    │   │   └── default.conf.j2
    │   ├── files/
    │   │   └── index.html
    │   └── defaults/main.yml
    └── database/                 # Rôle MySQL
        ├── tasks/main.yml
        ├── handlers/main.yml
        ├── templates/
        │   └── my.cnf.j2
        └── defaults/main.yml
```

---

## 🔐 Sécurité

### Bonnes pratiques appliquées

1. **Mots de passe** : Stockés dans vault.yml (chiffré)
2. **MySQL** : Sécurisation automatique avec `mysql_secure_installation`
3. **Nginx** : Certificats SSL auto-signés par défaut
4. **Firewall** : Ouverture des ports nécessaires uniquement
5. **SELinux** : Contextes adaptés pour les services

### Commandes de sécurisation

```bash
# Chiffrer les mots de passe
ansible-vault encrypt group_vars/all/vault.yml

# Modifier les mots de passe
ansible-vault edit group_vars/all/vault.yml

# Lancer avec le vault
ansible-playbook -i inventory/hosts.ini deploy_apps.yml --ask-vault-pass
```

---

## 🛠️ Dépannage

### Problème : nginx ne démarre pas

```bash
# Vérifier les logs
ansible webservers -i inventory/hosts.ini -m shell -a "journalctl -xe | grep nginx"

# Tester la configuration
ansible webservers -i inventory/hosts.ini -m shell -a "nginx -t"
```

### Problème : MySQL connection refused

```bash
# Vérifier que MySQL écoute
ansible databases -i inventory/hosts.ini -m shell -a "ss -tlnp | grep 3306"

# Vérifier les logs
ansible databases -i inventory/hosts.ini -m shell -a "journalctl -u mysql"
```

### Problème : Permission denied

```bash
# Vérifier l'utilisateur ansible
ansible all -i inventory/hosts.ini -m shell -a "whoami"

# Vérifier sudo
ansible all -i inventory/hosts.ini -b -m shell -a "whoami"
```

---

## 🎯 Intégration avec AWX

### Créer le Job Template pour les applications

1. **Project** : Pointer vers ce dépôt Git
2. **Inventory** : Importer depuis `inventory/hosts.ini`
3. **Job Templates** :
   - `Deploy Web Server` → `deploy_webserver.yml`
   - `Deploy Database` → `deploy_database.yml`
   - `Deploy Full Stack` → `deploy_apps.yml`

### Survey pour AWX

Questions à ajouter dans le survey :

| Question | Variable | Type | Défaut |
|----------|----------|------|--------|
| Nom du serveur | `nginx_server_name` | Text | `_` |
| Port HTTP | `nginx_port` | Integer | `80` |
| Activer SSL ? | `nginx_enable_ssl` | Boolean | `true` |
| Base de données | `mysql_database` | Text | `app_db` |
| Utilisateur DB | `mysql_user` | Text | `app_user` |

---

## 📝 Exercices supplémentaires

### Exercice 1 : Ajouter PHP-FPM

Créer un rôle `php` pour installer PHP-FPM et le connecter à nginx.

### Exercice 2 : Load Balancer

Configurer nginx comme load balancer entre plusieurs serveurs web.

### Exercice 3 : Monitoring

Ajouter un rôle pour installer Prometheus node_exporter.

### Exercice 4 : Backup automatique

Créer un playbook pour sauvegarder automatiquement la base de données.

---

## 📖 Ressources

- [Documentation nginx](https://nginx.org/en/docs/)
- [Documentation MySQL](https://dev.mysql.com/doc/)
- [Ansible nginx role](https://galaxy.ansible.com/nginxinc/nginx)
- [Ansible MySQL role](https://galaxy.ansible.com/geerlingguy/mysql)

---

## ✅ Checklist de validation

Avant de passer à l'atelier suivant :

- [ ] nginx installé et accessible sur le port 80
- [ ] Page web de test affichée
- [ ] MySQL installé et sécurisé
- [ ] Base de données créée avec utilisateur dédié
- [ ] Tests de connectivité réussis
- [ ] Playbooks intégrés dans AWX
- [ ] Documentation des mots de passe dans le vault