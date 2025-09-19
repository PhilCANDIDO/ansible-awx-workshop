#!/bin/bash
#
# Script de préparation automatique du template VMware
# À exécuter sur une VM Debian 12 fraîchement installée
#
# Usage: ./prepare-template.sh
#

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction de log
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERREUR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

# Vérifier que le script est lancé en root
if [[ $EUID -ne 0 ]]; then
   error "Ce script doit être exécuté en tant que root"
fi

log "=== Début de la préparation du template VMware ==="

# 1. Mise à jour du système
log "Mise à jour du système..."
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y

# 2. Installation des packages essentiels
log "Installation des packages système de base..."
apt-get install -y \
    sudo \
    openssh-server \
    curl \
    wget \
    vim \
    net-tools \
    htop \
    git \
    gnupg \
    lsb-release \
    ca-certificates

# 3. Installation des packages pour Ansible
log "Installation des packages Python pour Ansible..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-apt \
    python3-setuptools \
    aptitude \
    python3-jmespath

# 4. Installation de open-vm-tools
log "Installation de open-vm-tools..."
apt-get install -y open-vm-tools
systemctl enable open-vm-tools
systemctl start open-vm-tools

# 5. Création de l'utilisateur ansible
log "Création de l'utilisateur ansible..."
if ! id "ansible" &>/dev/null; then
    useradd -m -s /bin/bash ansible
    echo "ansible:ansible" | chpasswd
    log "Utilisateur ansible créé avec mot de passe par défaut"
else
    warning "L'utilisateur ansible existe déjà"
fi

# 6. Configuration sudo pour ansible
log "Configuration sudo pour l'utilisateur ansible..."
cat > /etc/sudoers.d/ansible << EOF
# Ansible user sudo configuration
ansible ALL=(ALL) NOPASSWD:ALL
EOF
chmod 440 /etc/sudoers.d/ansible

# 7. Configuration SSH pour ansible
log "Configuration SSH pour l'utilisateur ansible..."
mkdir -p /home/ansible/.ssh
chmod 700 /home/ansible/.ssh
touch /home/ansible/.ssh/authorized_keys
chmod 600 /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible/.ssh

# 8. Configuration SSH globale
log "Configuration du service SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

cat > /etc/ssh/sshd_config << EOF
# SSH Server configuration for VMware template
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Security
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Performance
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# Keep alive
ClientAliveInterval 60
ClientAliveCountMax 3
EOF

systemctl restart sshd
systemctl enable sshd

# 9. Configuration réseau en DHCP
log "Configuration du réseau en DHCP..."
# Détecter l'interface principale
PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

if [ -z "$PRIMARY_INTERFACE" ]; then
    warning "Impossible de détecter l'interface réseau principale"
    PRIMARY_INTERFACE="eth0"
fi

log "Interface réseau détectée : $PRIMARY_INTERFACE"

cat > /etc/network/interfaces << EOF
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto $PRIMARY_INTERFACE
iface $PRIMARY_INTERFACE inet dhcp
EOF

# 10. Installation optionnelle de cloud-init
read -p "Voulez-vous installer cloud-init ? (recommandé) [O/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    log "Installation de cloud-init..."
    apt-get install -y cloud-init

    cat > /etc/cloud/cloud.cfg.d/99_vmware.cfg << EOF
datasource_list: [ VMwareGuestInfo, None ]
disable_root: true
preserve_hostname: false

users:
  - default
  - name: ansible
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false

# Disable network configuration by cloud-init
network:
  config: disabled
EOF

    log "Cloud-init installé et configuré"
fi

# 11. Configuration du fuseau horaire
log "Configuration du fuseau horaire..."
timedatectl set-timezone Europe/Paris

# 12. Désactivation de services inutiles pour un template
log "Optimisation des services..."
systemctl disable bluetooth.service 2>/dev/null || true
systemctl disable cups.service 2>/dev/null || true

# 13. Configuration de la rotation des logs
log "Configuration de la rotation des logs..."
cat > /etc/logrotate.d/template << EOF
/var/log/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF

# 14. Création du script de nettoyage final
log "Création du script de nettoyage final..."
cat > /root/cleanup-before-template.sh << 'CLEANUP_SCRIPT'
#!/bin/bash
#
# Script de nettoyage final avant conversion en template
# À exécuter juste avant d'éteindre la VM
#

echo "=== Nettoyage final du système ==="

# Arrêter les services non essentiels
systemctl stop rsyslog

# Nettoyer l'historique apt
apt-get clean
apt-get autoclean
apt-get autoremove -y
rm -rf /var/cache/apt/*
rm -rf /var/lib/apt/lists/*

# Nettoyer les logs
find /var/log -type f -exec truncate -s 0 {} \;
rm -rf /var/log/*.gz
rm -rf /var/log/*.1
rm -rf /var/log/*.old
rm -rf /var/log/journal/*

# Nettoyer tmp
rm -rf /tmp/*
rm -rf /var/tmp/*

# Nettoyer l'historique
history -c
> ~/.bash_history
> /home/ansible/.bash_history

# Nettoyer les caches
rm -rf /var/cache/man/*
rm -rf /var/cache/fontconfig/*

# Réinitialiser les règles udev
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f /etc/udev/rules.d/75-persistent-net-generator.rules

# Supprimer les clés SSH de l'hôte
rm -f /etc/ssh/ssh_host_*

# Réinitialiser machine-id (TRÈS IMPORTANT pour le clonage)
> /etc/machine-id
rm -f /var/lib/dbus/machine-id

# Nettoyer cloud-init si présent
if command -v cloud-init &> /dev/null; then
    cloud-init clean --logs --seed
fi

# Synchroniser et libérer l'espace
sync
echo 3 > /proc/sys/vm/drop_caches

echo "=== Nettoyage terminé ==="
echo ""
echo "IMPORTANT : La VM est prête à être convertie en template"
echo "Étapes suivantes :"
echo "1. Arrêter la VM : shutdown -h now"
echo "2. Dans vCenter : Clic droit -> Clone to Template"
echo "3. Nommer le template : debian12-tpl"
echo ""
read -p "Appuyez sur Entrée pour éteindre la VM..."
shutdown -h now
CLEANUP_SCRIPT

chmod +x /root/cleanup-before-template.sh

# 15. Informations finales
log "=== Préparation du template terminée avec succès ==="
echo ""
warning "IMPORTANT - Prochaines étapes :"
echo ""
echo "1. Redémarrer la VM pour appliquer tous les changements :"
echo "   ${GREEN}reboot${NC}"
echo ""
echo "2. Après redémarrage, tester la connexion SSH avec l'utilisateur ansible"
echo ""
echo "3. Quand tout est prêt, lancer le script de nettoyage final :"
echo "   ${GREEN}/root/cleanup-before-template.sh${NC}"
echo ""
echo "4. La VM s'éteindra automatiquement"
echo ""
echo "5. Dans vCenter : Convertir la VM en template (Clone to Template)"
echo ""
log "Informations de connexion :"
echo "  - Utilisateur : ansible"
echo "  - Mot de passe : ansible"
echo "  - Sudo : NOPASSWD configuré"
echo ""