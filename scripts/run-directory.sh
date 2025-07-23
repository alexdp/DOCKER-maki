#!/bin/bash

set -e

# Script pour créer les répertoires nécessaires (fichiers, photos, vidéos, volumes Docker)

# Trouver un disque monté en écriture (chercher dans /mnt car c'est là que sont montés les disques de données)
FIRST_MOUNT=$(ls -1 /mnt 2>/dev/null | head -n 1)
if [ -n "$FIRST_MOUNT" ]; then
    FIRST_MOUNT="/mnt/$FIRST_MOUNT"
fi

if [ -z "$FIRST_MOUNT" ] || [ ! -d "$FIRST_MOUNT" ]; then
    echo "Aucun disque monté trouvé dans /mnt"
    exit 1
else
    echo "Disque monté en écriture trouvé : $FIRST_MOUNT"
    # Vérifier si on peut écrire sur ce disque
    if touch "$FIRST_MOUNT/.test_write" 2>/dev/null; then
        DOCKER_DATA_ROOT_DIR="$FIRST_MOUNT/.docker"
        rm -f "$FIRST_MOUNT/.test_write"
    else
        echo "Le disque $FIRST_MOUNT n'est pas accessible en écriture"
        exit 1
    fi
fi

export ROOT_DIR="$FIRST_MOUNT"
export PHOTOS_DIR="$ROOT_DIR/photos"
export VIDEOS_DIR="$ROOT_DIR/videos"
export FILES_DIR="$ROOT_DIR/files"
export DOCKER_DATA_ROOT_DIR="$ROOT_DIR/.docker"
export RCLONE_DIR="$ROOT_DIR/.rclone"


mkdir -p "$PHOTOS_DIR"
mkdir -p "$VIDEOS_DIR"
mkdir -p "$FILES_DIR"
mkdir -p "$DOCKER_DATA_ROOT_DIR"
mkdir -p "$RCLONE_DIR"
chmod 777 "$PHOTOS_DIR"
chmod 777 "$VIDEOS_DIR"
chmod 777 "$FILES_DIR"
chmod 700 "$DOCKER_DATA_ROOT_DIR"
chmod 777 "$RCLONE_DIR"
chown -R smbuser:smbuser "$PHOTOS_DIR"
chown -R smbuser:smbuser "$VIDEOS_DIR"
chown -R smbuser:smbuser "$FILES_DIR"
chown -R root:root "$RCLONE_DIR"
chown -R root:root "$DOCKER_DATA_ROOT_DIR"


