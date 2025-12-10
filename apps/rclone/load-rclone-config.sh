#!/bin/bash
set -e

# Charge les variables d'environnement depuis le config.env (generé par load-usb-config)
# pour obtenir STORAGE_LOCATION
if [ -f /run/config.env ]; then
    source /run/config.env
fi


# Définit les répertoires utilisés par RClone :
# -> celui utilisé pour stocker les tokens d'authentification
# -> celui où les remotes seront montés
WORKING_DIR=/tmp/.rclone
BASE_MOUNT_DIR="/mnt/cloud"
if [ -n "$STORAGE_LOCATION" ] && [ "$STORAGE_LOCATION" != "auto" ]; then
    WORKING_DIR="$STORAGE_LOCATION/.rclone"
    BASE_MOUNT_DIR="$STORAGE_LOCATION/cloud"
fi
if [ -z "$STORAGE_LOCATION" ] || [ "$STORAGE_LOCATION" == "auto" ]; then
    FIRST_MOUNT=$(ls -1 /mnt 2>/dev/null | head -n 1)
    if [ -n "$FIRST_MOUNT" ]; then
        FIRST_MOUNT="/mnt/$FIRST_MOUNT"
    fi
    if [ -d "$FIRST_MOUNT" ]; then
        echo "Disque monté en écriture trouvé : $FIRST_MOUNT"
        if touch "$FIRST_MOUNT/.test_write" 2>/dev/null; then
            rm -f "$FIRST_MOUNT/.test_write"
            WORKING_DIR="$FIRST_MOUNT/.rclone"
            BASE_MOUNT_DIR="$FIRST_MOUNT/cloud"
        else
            echo "Le disque $FIRST_MOUNT n'est pas accessible en écriture"
        fi
    fi
fi


# Définit les variables d'environnement RClone globales qui seront utilisées par rclone et le reste du script
export RCLONE_WORKING_DIR="$WORKING_DIR"
export RCLONE_BASE_MOUNT_DIR="$BASE_MOUNT_DIR"
export RCLONE_CONFIG="$WORKING_DIR/rclone.conf"
export RCLONE_CACHE_DIR="$WORKING_DIR"
export RCLONE_ALLOW_OTHER=true
export RCLONE_UMASK=000
export RCLONE_VFS_CACHE_MODE=full


# Crée l'utilisateur rclone
id -u rclone &>/dev/null || useradd -r -s /usr/sbin/nologin rclone
usermod -aG users rclone


# Prépare le répertoire de travail RClone
echo "Répertoire de travail RClone défini sur : $RCLONE_WORKING_DIR"
if [ ! -d "$RCLONE_WORKING_DIR" ]; then
    echo "Création du répertoire de travail RClone : $RCLONE_WORKING_DIR"
    mkdir -p "$RCLONE_WORKING_DIR"
fi
chown -R rclone:users "$RCLONE_WORKING_DIR"
chmod g+rw "$RCLONE_WORKING_DIR"
setfacl -d -m g:users:rwX $RCLONE_WORKING_DIR

# Prépare le répertoire de cache RClone
if [ ! -d "$RCLONE_CACHE_DIR" ]; then
    echo "Création du répertoire de cache RClone : $RCLONE_CACHE_DIR"
    mkdir -p "$RCLONE_CACHE_DIR"
fi
chown -R rclone:users "$RCLONE_CACHE_DIR"
chmod g+rw "$RCLONE_CACHE_DIR"
setfacl -d -m g:users:rwX $RCLONE_CACHE_DIR


# Crée le fichier de configuration RClone et lui applique les bonnes permissions
# afin qu'on puisse y contribuer depuis n'importe quelle session shell utilisateur du groupe users
if [ ! -f "$RCLONE_CONFIG" ]; then
    echo "Création du fichier de configuration RClone : $RCLONE_CONFIG"
    touch "$RCLONE_CONFIG"
    chown rclone:users "$RCLONE_CONFIG"
    chmod 660 "$RCLONE_CONFIG"
fi


# Exporte les variables d'environnement RClone globales pour permettre d'utiliser Rclone depuis le bash
sudo sed -i '/^RCLONE_/d' /etc/environment
env | grep '^RCLONE_' | sudo tee -a /etc/environment > /dev/null

# Exporte également dans /run/config.env pour les autres scripts de l'application
if [ -f /run/config.env ]; then
    sudo sed -i '/^RCLONE_/d' /run/config.env
    env | grep '^RCLONE_' | sudo tee -a /run/config.env > /dev/null
fi

