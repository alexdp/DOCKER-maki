#!/bin/bash

set -e

# Préparation de l'environnement Rclone
RCLONE_DATA_ROOT_DIR="/tmp/rclone"
# Trouver un disque monté en écriture (chercher dans /mnt car c'est là que sont montés les disques de données)
FIRST_MOUNT=$(ls -1 /mnt 2>/dev/null | head -n 1)
if [ -n "$FIRST_MOUNT" ]; then
    FIRST_MOUNT="/mnt/$FIRST_MOUNT"
fi

if [ -z "$FIRST_MOUNT" ] || [ ! -d "$FIRST_MOUNT" ]; then
    echo "Aucun disque monté en écriture trouvé dans /mnt. Rclone utilisera /tmp/rclone"
    # Vérifier si on peut écrire dans /tmp
    if ! touch /tmp/test_write 2>/dev/null; then
        echo "Impossible d'écrire dans /tmp, utilisation de /var/lib/rclone"
        RCLONE_DATA_ROOT_DIR="/var/lib/rclone"
    else
        rm -f /tmp/test_write
    fi
else
    echo "Disque monté en écriture trouvé : $FIRST_MOUNT"
    # Vérifier si on peut écrire sur ce disque
    if touch "$FIRST_MOUNT/.test_write" 2>/dev/null; then
        RCLONE_DATA_ROOT_DIR="$FIRST_MOUNT/.rclone"
        rm -f "$FIRST_MOUNT/.test_write"
    else
        echo "Le disque $FIRST_MOUNT n'est pas accessible en écriture, utilisation de /tmp/rclone"
    fi
fi
mkdir -p "$RCLONE_DATA_ROOT_DIR"
chmod 775 "$RCLONE_DATA_ROOT_DIR"


# Déclarer la variable d'environnement pour le fichier de configuration rclone
cat > /etc/profile.d/rclone.sh << EOF
export RCLONE_CONFIG=$RCLONE_DATA_ROOT_DIR/config/rclone.conf
EOF
chmod 777 /etc/profile.d/rclone.sh

# Créer un lien symbolique du rclone.conf pour le compte root
mkdir -p /root/.config/rclone
ln -sf "$RCLONE_DATA_ROOT_DIR/config/rclone.conf" /root/.config/rclone/rclone.conf




