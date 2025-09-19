# Spécifications du Template VMware pour l'Atelier

## 📋 Vue d'ensemble

Ce document décrit les prérequis et la configuration nécessaire pour créer le template VM `debian12-tpl` utilisé dans l'atelier de déploiement VMware.

---

## 🖥️ Configuration matérielle du template

### Ressources minimales
- **vCPU** : 1
- **RAM** : 1024 Mo
- **Disque** : 10 Go (thin provisioning)
- **Contrôleur SCSI** : VMware Paravirtual
- **Carte réseau** : VMXNET3
- **Firmware** : BIOS (compatible avec UEFI optionnel)

---

## 💿 Installation du système d'exploitation

### Système de base
- **OS** : Debian 12 (Bookworm) - Version minimale
- **Architecture** : 64 bits
- **Kernel** : Version standard Debian

### Partitionnement recommandé

#### Option 1 : LVM (RECOMMANDÉ pour la flexibilité)
```
/boot     - 512 Mo  - ext4  - Partition primaire
/         - 8 Go    - ext4  - LVM (vg_root/lv_root)
swap      - 1 Go    - swap  - LVM (vg_root/lv_swap)
```

#### Option 2 : Partitionnement simple
```
/         - 9 Go    - ext4  - Partition primaire
swap      - 1 Go    - swap  - Partition primaire
```

### Points importants
- ✅ **LVM recommandé** pour permettre l'extension future des partitions
- ✅ **Pas de partition /home séparée** pour simplifier la gestion
- ✅ **Swap obligatoire** pour éviter les problèmes de mémoire

---

## 🌐 Configuration réseau

### Interface réseau principale (eth0 ou ens192)
```yaml
Configuration: DHCP
IPv4: Automatique
IPv6: Désactivé (optionnel)
DNS: Automatique via DHCP
```

### Fichier `/etc/network/interfaces`
```bash
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp
```

### Important
- ✅ **DHCP obligatoire** pour le clonage automatique
- ✅ L'IP statique sera configurée par Ansible lors du déploiement

---

## 📦 Packages essentiels à installer

### Packages système de base
```bash
apt-get update
apt-get install -y \
    sudo \
    openssh-server \
    curl \
    wget \
    vim \
    net-tools \
    htop \
    git
```

### Packages pour Ansible
```bash
apt-get install -y \
    python3 \
    python3-pip \
    python3-apt \
    python3-setuptools \
    aptitude
```

### Packages VMware Tools
```bash
# Option 1 : open-vm-tools (recommandé)
apt-get install -y open-vm-tools

# Option 2 : VMware Tools officiels (si requis)
# Installer depuis vSphere
```

---

## 👤 Configuration des utilisateurs

### Utilisateur root
- Mot de passe : `P@ssw0rd` (à changer après déploiement)
- SSH : Désactivé par défaut

### Utilisateur ansible
```bash
# Créer l'utilisateur
useradd -m -s /bin/bash ansible
echo "ansible:ansible" | chpasswd

# Configuration sudo sans mot de passe
echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible
```

### Configuration SSH pour ansible
```bash
# Créer le répertoire .ssh
mkdir -p /home/ansible/.ssh
chmod 700 /home/ansible/.ssh

# Préparer pour les clés SSH (sera configuré par Ansible)
touch /home/ansible/.ssh/authorized_keys
chmod 600 /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible/.ssh
```

---

## ⚙️ Configuration SSH

### Fichier `/etc/ssh/sshd_config`
```bash
# Autoriser l'authentification par clé
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Autoriser temporairement le mot de passe (sera désactivé après)
PasswordAuthentication yes

# Désactiver root SSH (sécurité)
PermitRootLogin no

# Autres paramètres de sécurité
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
```

### Redémarrer SSH
```bash
systemctl restart sshd
systemctl enable sshd
```

---

## 🚀 Cloud-Init (Optionnel mais recommandé)

### Installation
```bash
apt-get install -y cloud-init
```

### Configuration `/etc/cloud/cloud.cfg`
```yaml
datasource_list: [ VMwareGuestInfo, None ]
disable_root: false
preserve_hostname: false

users:
  - default
  - name: ansible
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false

# Désactiver la configuration réseau par cloud-init
network:
  config: disabled
```

### Nettoyage avant conversion en template
```bash
# Nettoyer cloud-init
cloud-init clean --logs --seed

# Réinitialiser machine-id
rm -f /etc/machine-id
touch /etc/machine-id
```

---

## 🧹 Préparation finale du template

### Script de nettoyage avant conversion
```bash
#!/bin/bash
# cleanup-template.sh

echo "=== Nettoyage du système pour template ==="

# Nettoyer l'historique apt
apt-get clean
apt-get autoclean
apt-get autoremove -y

# Nettoyer les logs
find /var/log -type f -exec truncate -s 0 {} \;
rm -rf /var/log/*.gz
rm -rf /var/log/*.[0-9]

# Nettoyer tmp
rm -rf /tmp/*
rm -rf /var/tmp/*

# Nettoyer l'historique bash
history -c
cat /dev/null > ~/.bash_history

# Nettoyer les caches
rm -rf /var/cache/apt/*
rm -rf /var/cache/man/*

# Réinitialiser l'interface réseau
rm -f /etc/udev/rules.d/70-persistent-net.rules

# Nettoyer SSH host keys (seront régénérées au premier boot)
rm -f /etc/ssh/ssh_host_*

# Machine ID (important pour le clonage)
echo "" > /etc/machine-id

# Si cloud-init installé
if [ -x "$(command -v cloud-init)" ]; then
    cloud-init clean --logs --seed
fi

echo "=== Nettoyage terminé ==="
echo "Arrêter la VM et la convertir en template dans vCenter"
```

### Exécuter le nettoyage
```bash
chmod +x cleanup-template.sh
./cleanup-template.sh
shutdown -h now
```

---

## ✅ Checklist de validation du template

Avant de convertir la VM en template, vérifier :

- [ ] **Système d'exploitation**
  - [ ] Debian 12 installé et à jour
  - [ ] Partitionnement LVM configuré
  - [ ] Swap activé

- [ ] **Réseau**
  - [ ] Interface en DHCP
  - [ ] Connectivité réseau fonctionnelle
  - [ ] Résolution DNS opérationnelle

- [ ] **Packages**
  - [ ] Python3 installé
  - [ ] open-vm-tools installé et actif
  - [ ] SSH server installé et démarré

- [ ] **Utilisateurs**
  - [ ] Utilisateur ansible créé
  - [ ] Sudo sans mot de passe configuré
  - [ ] Répertoire .ssh préparé

- [ ] **Sécurité**
  - [ ] Root SSH désactivé
  - [ ] Firewall de base (optionnel)

- [ ] **Nettoyage**
  - [ ] Historiques nettoyés
  - [ ] Logs vidés
  - [ ] Machine-id réinitialisé
  - [ ] SSH host keys supprimées

---

## 🔄 Conversion en template dans vCenter

### Étapes dans vSphere
1. Éteindre la VM (`shutdown -h now`)
2. Clic droit sur la VM → **Clone** → **Clone to Template**
3. Nommer le template : `debian12-tpl`
4. Sélectionner le datacenter et le dossier
5. Valider la création

### Vérification
- Le template apparaît dans **VMs and Templates**
- Icône différente (template vs VM)
- Non modifiable directement

---

## 📝 Notes importantes

### Pour le formateur
1. **Créer plusieurs templates** si besoin (Ubuntu, Rocky Linux, etc.)
2. **Documenter les credentials** du template pour les élèves
3. **Tester le clonage** avant l'atelier
4. **Prévoir un template de secours**

### Pour les élèves
1. **Ne pas modifier** le template directement
2. **Toujours cloner** depuis le template
3. **Personnaliser après** le clonage via Ansible

---

## 🆘 Dépannage courant

### Problème : La VM clonée n'a pas d'IP
**Solution** : Vérifier que le DHCP est actif sur le réseau VMware

### Problème : open-vm-tools ne fonctionne pas
**Solution** :
```bash
systemctl restart open-vm-tools
systemctl status open-vm-tools
```

### Problème : SSH refuse la connexion
**Solution** : Vérifier que les SSH host keys sont régénérées
```bash
ssh-keygen -A
systemctl restart sshd
```

### Problème : Le hostname n'est pas unique
**Solution** : S'assurer que machine-id est vide dans le template

---

## 📚 Ressources

- [Debian 12 Installation Guide](https://www.debian.org/releases/stable/installmanual)
- [VMware Guest OS Compatibility](https://www.vmware.com/resources/compatibility/search.php)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
- [Best Practices for VMware Templates](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-17BEDA21-43F6-41F4-8FB2-E01D275FE9B4.html)