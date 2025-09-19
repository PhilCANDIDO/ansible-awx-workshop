# 🔧 Correction du problème SSH après clonage

## Problème identifié

Les VMs clonées depuis le template ne peuvent pas démarrer SSH car :
- Les clés d'hôte SSH ont été supprimées dans le template (sécurité)
- Elles ne sont pas régénérées automatiquement au premier boot

**Erreur** : `ssh.service: Failed with result 'exit-code'`

## Solutions

### Solution 1 : Via la console vCenter (RECOMMANDÉ)

1. Ouvrir la console de la VM dans vCenter
2. Se connecter avec l'utilisateur `ansible` (mot de passe: `ansible`)
3. Exécuter les commandes suivantes :

```bash
# Passer en root
sudo su -

# Régénérer toutes les clés SSH
ssh-keygen -A

# Vérifier que les clés sont créées
ls -la /etc/ssh/ssh_host_*

# Redémarrer le service SSH
systemctl restart ssh.service

# Vérifier le statut
systemctl status ssh.service
```

### Solution 2 : Via VMware Tools (automatisé)

Exécuter le playbook de correction :

```bash
cd 02-deploiement-vm-vmware/
ansible-playbook -i inventory/hosts.ini fix-ssh-keys.yml --ask-vault-pass
```

### Solution 3 : Prévention dans le template

Modifier le script de préparation du template pour ajouter un service de régénération automatique.

Créer le fichier `/etc/systemd/system/regenerate-ssh-keys.service` :

```ini
[Unit]
Description=Regenerate SSH host keys
Before=ssh.service
ConditionFileNotEmpty=!/etc/ssh/ssh_host_rsa_key

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Activer le service :
```bash
systemctl enable regenerate-ssh-keys.service
```

## Vérification

Après correction, vérifier :

```bash
# Sur la VM
systemctl status ssh.service

# Depuis le controller Ansible
ssh ansible@<IP_VM>
```

## Pour éviter ce problème à l'avenir

### Option A : Utiliser cloud-init

Cloud-init régénère automatiquement les clés SSH. S'assurer qu'il est installé et configuré dans le template.

### Option B : Script de post-déploiement

Ajouter une tâche dans le rôle `vmware_vm_deploy` pour régénérer les clés via VMware Tools après création.

### Option C : Service systemd

Créer un service systemd qui vérifie et régénère les clés au démarrage si elles sont manquantes.