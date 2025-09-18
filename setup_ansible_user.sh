#!/bin/bash

set -e

USER="ansible"
SSH_DIR="/home/$USER/.ssh"
PRIVATE_KEY="$SSH_DIR/id_ed25519"
PUBLIC_KEY="$SSH_DIR/id_ed25519.pub"
SUDOERS_FILE="/etc/sudoers.d/$USER"

echo "### Étape 1 : Création de l'utilisateur '$USER' s'il n'existe pas..."
if id "$USER" &>/dev/null; then
    echo "[INFO] Utilisateur '$USER' existe déjà."
else
    adduser --disabled-password --gecos "" "$USER"
    echo "[OK] Utilisateur '$USER' créé."
fi

echo "### Étape 2 : Génération de la paire de clés SSH si nécessaire..."
mkdir -p "$SSH_DIR"
chown "$USER:$USER" "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ -f "$PRIVATE_KEY" && -f "$PUBLIC_KEY" ]]; then
    echo "[INFO] Clé SSH déjà présente pour '$USER'."
else
    sudo -u "$USER" ssh-keygen -t ed25519 -f "$PRIVATE_KEY" -N "" -C "$USER@$(hostname)"
    echo "[OK] Paire de clés SSH générée pour '$USER'."
fi

echo "### Étape 3 : Configuration des droits sudo sans mot de passe..."
echo "$USER ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"
echo "[OK] Droits sudo configurés dans $SUDOERS_FILE"

echo
echo "##########################################"
echo "# Clé publique à distribuer aux managed nodes :"
echo "##########################################"
cat "$PUBLIC_KEY"

echo
echo "##########################################"
echo "# Clé privée (à conserver en sécurité) :"
echo "##########################################"
cat "$PRIVATE_KEY"

echo
echo "### Étape 4 : Instructions pour connecter un managed node"

echo "
1. Connectez-vous au managed node en root ou avec un compte existant.
2. Créez l'utilisateur '$USER' s'il n'existe pas :

   adduser --disabled-password --gecos \"\" $USER

3. Créez le dossier ~/.ssh pour cet utilisateur :

   mkdir -p /home/$USER/.ssh
   chmod 700 /home/$USER/.ssh
   chown $USER:$USER /home/$USER/.ssh

4. Copiez la clé publique affichée ci-dessus dans :

   /home/$USER/.ssh/authorized_keys

   Assurez-vous que les permissions sont correctes :

   chmod 600 /home/$USER/.ssh/authorized_keys
   chown $USER:$USER /home/$USER/.ssh/authorized_keys

5. (Optionnel) Donnez-lui les droits sudo sans mot de passe :

   echo \"$USER ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/$USER
   chmod 440 /etc/sudoers.d/$USER

"

echo "[FIN] Configuration du control node terminée."
