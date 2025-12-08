#!/bin/bash
set -e


# Charger les variables d'environnement depuis le config.env (generé par load-usb-config)
if [ -f /run/config.env ]; then
    source /run/config.env
fi

# Ajoute l'utilisateur jellyfin au groupe users
if id -u jellyfin >/dev/null 2>&1; then
    usermod -aG users jellyfin
fi


# Définition de STORAGE_VIDEO en s'appuyant sur STORAGE_LOCATION ou, par défaut, /tmp/share/videos
# et définition du répertoire de travail de Jellyfin
STORAGE_VIDEO="/tmp/share/videos"
WORKING_DIR="/tmp/.jellyfin"
if [ -n "$STORAGE_LOCATION" ] && [ "$STORAGE_LOCATION" != "auto" ]; then
    STORAGE_VIDEO="$STORAGE_LOCATION/videos"
    WORKING_DIR="$STORAGE_LOCATION/.jellyfin"
fi
if [ "$STORAGE_LOCATION" == "auto" ] || [ -z "$STORAGE_LOCATION" ]; then
    FIRST_MOUNT=$(ls -1 /mnt 2>/dev/null | head -n 1)
    if [ -n "$FIRST_MOUNT" ]; then
        FIRST_MOUNT="/mnt/$FIRST_MOUNT"
    fi
    if [ -d "$FIRST_MOUNT" ]; then
        echo "Disque monté en écriture trouvé : $FIRST_MOUNT"
        if touch "$FIRST_MOUNT/.test_write" 2>/dev/null; then
            rm -f "$FIRST_MOUNT/.test_write"
            # Définir le répertoire de stockage Jellyfin
            STORAGE_VIDEO="$FIRST_MOUNT/videos"
            WORKING_DIR="$FIRST_MOUNT/.jellyfin"
        else
            echo "Le disque $FIRST_MOUNT n'est pas accessible en écriture"
        fi
    fi
fi

echo "Répertoire de stockage Jellyfin défini sur : $STORAGE_VIDEO"
echo "Répertoire de travail Jellyfin défini sur : $WORKING_DIR"

echo "Préparation des répertoires Jellyfin..."
if [ ! -d "$STORAGE_VIDEO" ]; then
    echo "Création du répertoire de stockage vidéo de Jellyfin : $STORAGE_VIDEO"
    mkdir -p "$STORAGE_VIDEO"
    chown jellyfin:users "$STORAGE_VIDEO"
fi
chmod g+rw "$STORAGE_VIDEO"
setfacl -d -m g:users:rwX $STORAGE_VIDEO
if [ ! -d "$WORKING_DIR" ]; then
    echo "Création du répertoire de travail de Jellyfin : $WORKING_DIR"
    mkdir -p "$WORKING_DIR/data"
    mkdir -p "$WORKING_DIR/log"
    mkdir -p "$WORKING_DIR/cache"
    chown jellyfin:jellyfin "$WORKING_DIR"
fi

echo "Configuration de Jellyfin pour utiliser le répertoire de travail personnalisé..."
JELLYFIN_ENV_FILE="/etc/default/jellyfin"
sed -i "s|JELLYFIN_DATA_DIR\\s*=\\s*.*$|JELLYFIN_DATA_DIR=\"$WORKING_DIR/data\"|g" $JELLYFIN_ENV_FILE
sed -i "s|JELLYFIN_CACHE_DIR\\s*=\\s*.*$|JELLYFIN_CACHE_DIR=\"$WORKING_DIR/cache\"|g" $JELLYFIN_ENV_FILE
sed -i "s|JELLYFIN_LOG_DIR\\s*=\\s*.*$|JELLYFIN_LOG_DIR=\"$WORKING_DIR/log\"|g" $JELLYFIN_ENV_FILE