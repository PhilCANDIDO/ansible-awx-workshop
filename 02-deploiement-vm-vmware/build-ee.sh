#!/bin/bash
# Script pour construire l'Execution Environment pour AWX
# Prérequis : ansible-builder installé

set -e

echo "🔨 Construction de l'Execution Environment VMware Workshop"

# Vérifier que ansible-builder est installé
if ! command -v ansible-builder &> /dev/null; then
    echo "❌ ansible-builder n'est pas installé"
    echo "Installation : pip3 install ansible-builder"
    exit 1
fi

# Nom et tag de l'image
EE_NAME="vmware-workshop-ee"
EE_VERSION="1.0.0"
REGISTRY="localhost"  # Remplacer par votre registry

# Construire l'EE
echo "📦 Build de l'image ${EE_NAME}:${EE_VERSION}"
ansible-builder build \
    --file execution-environment.yml \
    --tag "${REGISTRY}/${EE_NAME}:${EE_VERSION}" \
    --tag "${REGISTRY}/${EE_NAME}:latest" \
    --container-runtime podman \
    --verbosity 2

echo "✅ Build terminé avec succès"

# Optionnel : Pousser vers un registry
echo ""
echo "Pour pousser l'image vers un registry :"
echo "  podman push ${REGISTRY}/${EE_NAME}:${EE_VERSION}"
echo "  podman push ${REGISTRY}/${EE_NAME}:latest"

# Tester l'EE localement
echo ""
echo "Pour tester l'EE localement :"
echo "  ansible-navigator run playbook_vmware.yml --execution-environment-image ${REGISTRY}/${EE_NAME}:latest --mode stdout"