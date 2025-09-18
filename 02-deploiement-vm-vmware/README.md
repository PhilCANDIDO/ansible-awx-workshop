# Atelier 02 – Déploiement de VM sur VMware avec Ansible

## 🎯 Objectifs de l'atelier

Dans cet atelier, vous allez apprendre à :
- ✅ Utiliser la collection `community.vmware` pour interagir avec vCenter
- ✅ Créer un rôle Ansible réutilisable pour déployer des VMs
- ✅ Gérer les variables sensibles avec Ansible Vault
- ✅ Intégrer votre playbook dans AWX avec un formulaire interactif
- ✅ Valider le déploiement dans l'interface vSphere

---

## 📋 Prérequis

### Logiciels requis
- ✅ Ansible ≥ 2.16 installé sur votre poste
- ✅ Python 3.8+ avec le module `pyvmomi`
- ✅ Git et VSCode configurés (voir atelier 01)

### Infrastructure VMware
- ✅ Accès à un serveur vCenter (URL, login, mot de passe)
- ✅ Un template VM Linux préparé dans vCenter (Debian 12 ou Ubuntu 22.04)
- ✅ Un datastore avec au moins 50 Go d'espace libre
- ✅ Un réseau VMware configuré (généralement "VM Network")

---

## 🚀 Installation rapide

### Étape 1 : Installer les collections Ansible requises

```bash
cd 02-deploiement-vm-vmware/
ansible-galaxy collection install -r requirements.yml
```

### Étape 2 : Configurer les accès vCenter

```bash
# Copier le fichier d'exemple
cp group_vars/all/vault.yml.example group_vars/all/vault.yml

# Éditer avec vos vraies valeurs vCenter
nano group_vars/all/vault.yml

# Chiffrer le fichier pour sécuriser les mots de passe
ansible-vault encrypt group_vars/all/vault.yml
```

### Étape 3 : Tester le déploiement

```bash
# Déploiement simple avec les valeurs par défaut
ansible-playbook -i inventory/hosts.ini playbook_vmware.yml --ask-vault-pass

# Déploiement avec des paramètres personnalisés
ansible-playbook -i inventory/hosts.ini playbook_vmware.yml --ask-vault-pass \
  -e "vm_name=web-server-01 vm_cpu=4 vm_memory=8192 vm_disk=50"
```

---

## 📊 Variables disponibles

Voici toutes les variables que vous pouvez personnaliser :

### Variables de la VM

| Variable       | Description                         | Valeur par défaut | Exemple        |
| -------------- | ----------------------------------- | ----------------- | -------------- |
| `vm_name`      | Nom de la VM à créer                | `ansible-vm-XXX`  | `web-server-01` |
| `vm_cpu`       | Nombre de processeurs virtuels      | `2`               | `4`            |
| `vm_memory`    | RAM en Mo (1024 Mo = 1 Go)          | `2048`            | `8192`         |
| `vm_disk`      | Taille du disque dur en Go          | `20`              | `50`           |
| `vm_state`     | État de la VM après création        | `poweredon`       | `poweredoff`   |

### Variables réseau (optionnelles)

| Variable       | Description                         | Valeur par défaut | Exemple            |
| -------------- | ----------------------------------- | ----------------- | ------------------ |
| `vm_network`   | Nom du réseau VMware                | `VM Network`      | `VLAN-100`         |
| `vm_ip`        | IP statique (vide = DHCP)           | ` ` (vide)        | `192.168.1.100`    |
| `vm_netmask`   | Masque de sous-réseau               | ` ` (vide)        | `255.255.255.0`    |
| `vm_gateway`   | Passerelle par défaut               | ` ` (vide)        | `192.168.1.1`      |

### Variables vCenter (obligatoires)

| Variable           | Description                    | À définir dans        |
| ------------------ | ------------------------------ | --------------------- |
| `vcenter_hostname` | URL ou IP du serveur vCenter   | `vault.yml`           |
| `vcenter_username` | Nom d'utilisateur vCenter      | `vault.yml`           |
| `vcenter_password` | Mot de passe vCenter           | `vault.yml`           |
| `vcenter_datacenter` | Nom du datacenter VMware     | `vault.yml`           |
| `vm_template`      | Template source à cloner       | `defaults/main.yml`   |
| `vm_datastore`     | Datastore pour stocker la VM   | `defaults/main.yml`   |
| `vm_folder`        | Dossier dans vCenter           | `defaults/main.yml`   |

---

## 💻 Exemples d'utilisation

### Exemple 1 : VM de développement simple

```bash
ansible-playbook -i inventory/hosts.ini playbook_vmware.yml --ask-vault-pass \
  -e "vm_name=dev-server"
```

### Exemple 2 : VM de production avec plus de ressources

```bash
ansible-playbook -i inventory/hosts.ini playbook_vmware.yml --ask-vault-pass \
  -e "vm_name=prod-db-01 vm_cpu=8 vm_memory=16384 vm_disk=100"
```

### Exemple 3 : VM avec IP statique

```bash
ansible-playbook -i inventory/hosts.ini playbook_vmware.yml --ask-vault-pass \
  -e "vm_name=web-server vm_ip=192.168.1.50 vm_netmask=255.255.255.0 vm_gateway=192.168.1.1"
```

---

## 🔧 Intégration avec AWX

### Étape 1 : Créer le projet dans AWX

1. Dans AWX, aller dans **Projects** → **Add**
2. Remplir :
   - **Name**: `Atelier-02-VMware`
   - **Organization**: Votre organisation
   - **SCM Type**: Git
   - **SCM URL**: URL de votre dépôt GitLab/GitHub
   - **SCM Branch**: `main`
3. Cliquer sur **Save**

### Étape 2 : Créer les credentials

1. Aller dans **Credentials** → **Add**
2. Créer un credential de type **VMware vCenter**:
   - **Name**: `vCenter-Credentials`
   - **Host**: Votre serveur vCenter
   - **Username**: Votre utilisateur vCenter
   - **Password**: Votre mot de passe

### Étape 3 : Créer le Job Template

1. Aller dans **Templates** → **Add** → **Job Template**
2. Configurer :
   - **Name**: `Deploy VMware VM`
   - **Project**: `Atelier-02-VMware`
   - **Playbook**: `02-deploiement-vm-vmware/playbook_vmware.yml`
   - **Credentials**: `vCenter-Credentials`
   - **Variables**: Ajouter les variables vault si nécessaire

### Étape 4 : Créer le Survey (formulaire)

1. Dans le Job Template, cliquer sur **Survey**
2. Activer le Survey et ajouter ces questions :

| Question              | Variable    | Type    | Défaut  | Requis |
|----------------------|-------------|---------|---------|--------|
| Nom de la VM         | `vm_name`   | Text    | -       | Oui    |
| Nombre de CPU        | `vm_cpu`    | Integer | `2`     | Oui    |
| RAM (Mo)             | `vm_memory` | Integer | `2048`  | Oui    |
| Disque (Go)          | `vm_disk`   | Integer | `20`    | Oui    |
| Réseau               | `vm_network`| Choice  | VM Network | Oui |
| Adresse IP (optionnel)| `vm_ip`    | Text    | -       | Non    |

3. Sauvegarder le Survey

### Étape 5 : Lancer le déploiement

1. Cliquer sur **Launch** 🚀
2. Remplir le formulaire avec vos valeurs
3. Cliquer sur **Next** puis **Launch**
4. Suivre l'exécution dans la vue des jobs

---

## 🛠️ Dépannage et erreurs courantes

### Erreur : "Unable to connect to vCenter"

**Cause** : Les credentials vCenter sont incorrects ou le serveur n'est pas accessible.

**Solution** :
```bash
# Vérifier la connectivité
ping vcenter.example.com

# Vérifier les credentials
ansible-vault edit group_vars/all/vault.yml
```

### Erreur : "Template not found"

**Cause** : Le template spécifié n'existe pas dans vCenter.

**Solution** : Vérifier le nom exact du template dans vCenter et mettre à jour la variable `vm_template`.

### Erreur : "Datastore full"

**Cause** : Plus assez d'espace sur le datastore.

**Solution** : Choisir un autre datastore ou libérer de l'espace.

### La VM se crée mais n'a pas d'IP

**Cause** : Le réseau n'a pas de DHCP ou la VM n'est pas encore démarrée.

**Solution** :
- Attendre quelques minutes après le déploiement
- Vérifier que le réseau VMware a un serveur DHCP actif
- Utiliser une IP statique avec les variables `vm_ip`, `vm_netmask`, `vm_gateway`

---

## 📚 Structure des fichiers du projet

```
02-deploiement-vm-vmware/
├── playbook_vmware.yml           # Playbook principal
├── requirements.yml               # Collections Ansible requises
├── inventory/
│   └── hosts.ini                 # Inventaire Ansible
├── group_vars/
│   └── all/
│       ├── main.yml              # Variables globales
│       ├── vault.yml.example     # Exemple pour les secrets
│       └── vault.yml             # Secrets chiffrés (à créer)
└── roles/
    └── vmware_vm_deploy/         # Rôle de déploiement
        ├── defaults/
        │   └── main.yml          # Valeurs par défaut
        ├── tasks/
        │   └── main.yml          # Tâches du rôle
        ├── vars/
        │   └── main.yml          # Variables du rôle
        ├── templates/
        │   └── cloud_init.cfg.j2 # Template cloud-init
        └── meta/
            └── main.yml          # Métadonnées du rôle
```

---

## 🎓 Points d'apprentissage

Après cet atelier, vous saurez :

1. **Utiliser Ansible Vault** pour sécuriser les mots de passe
2. **Créer un rôle Ansible** réutilisable et paramétrable
3. **Interagir avec vCenter** via la collection community.vmware
4. **Gérer des variables** à plusieurs niveaux (defaults, group_vars, extra_vars)
5. **Intégrer dans AWX** avec des formulaires interactifs (Survey)
6. **Débugger** les problèmes courants de déploiement VMware

---

## 📝 Exercices supplémentaires

### Exercice 1 : Déployer plusieurs VMs

Modifier le playbook pour déployer 3 VMs web en une seule exécution.

**Indice** : Utilisez une boucle `with_items` ou `loop`.

### Exercice 2 : Ajouter un second disque

Modifier le rôle pour ajouter un second disque de données à la VM.

**Indice** : Regardez la section `disk` du module `vmware_guest`.

### Exercice 3 : Personnalisation post-déploiement

Ajouter une tâche qui installe automatiquement nginx sur la VM après sa création.

**Indice** : Utilisez `add_host` pour ajouter la VM à l'inventaire dynamique.

---

## 📖 Ressources utiles

- [Documentation officielle community.vmware](https://docs.ansible.com/ansible/latest/collections/community/vmware/)
- [Module vmware_guest](https://docs.ansible.com/ansible/latest/collections/community/vmware/vmware_guest_module.html)
- [Guide Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [Best Practices Ansible](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

---

## ✅ Checklist de validation

Avant de passer à l'atelier suivant, vérifiez que vous savez :

- [ ] Installer une collection Ansible avec `ansible-galaxy`
- [ ] Créer et chiffrer un fichier avec `ansible-vault`
- [ ] Écrire un playbook qui utilise un rôle
- [ ] Passer des variables en ligne de commande avec `-e`
- [ ] Créer un Job Template dans AWX
- [ ] Configurer un Survey dans AWX
- [ ] Débugger une erreur de connexion vCenter
- [ ] Vérifier le déploiement dans l'interface vSphere