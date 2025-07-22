#!/bin/bash

# Script d'installation et configuration de Samba

set -e

echo "=== Installation du serveur Samba ==="

# Mise à jour et installation des paquets Samba
apt update
apt install -y samba samba-common-bin

# Crée l'utilisateur Samba pour le dossier partagé
adduser --system --no-create-home --group smbuser

# Activer les services Samba
systemctl enable smbd
systemctl enable nmbd


