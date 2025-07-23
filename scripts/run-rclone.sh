#!/bin/bash

# Script pour préparer la configuration de Rclone

set -e


# Déclarer la variable d'environnement pour le fichier de configuration rclone
cat > /etc/profile.d/rclone.sh << EOF
export RCLONE_CONFIG=$RCLONE_DIR/config/rclone.conf
EOF
chmod 777 /etc/profile.d/rclone.sh

# Créer un lien symbolique du rclone.conf pour le compte root
mkdir -p /root/.config/rclone
ln -sf "$RCLONE_DIR/config/rclone.conf" /root/.config/rclone/rclone.conf




