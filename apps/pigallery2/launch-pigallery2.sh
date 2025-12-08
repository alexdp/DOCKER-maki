#!/bin/bash
set -e

# Creation du user pigallery2 s'il n'existe pas, membre du groupe users
if ! id -u pigallery2 >/dev/null 2>&1; then
    echo "Création de l'utilisateur pigallery2..."
    useradd -r -s /bin/false pigallery2
    usermod -aG users pigallery2
fi


# Charger les variables d'environnement depuis le config.env (generé par load-usb-config)
if [ -f /run/config.env ]; then
    source /run/config.env
fi


# Définition de STORAGE_PHOTO en s'appuyant sur STORAGE_LOCATION ou, par défaut, /tmp/share/photo
# et définiftion du repertoire de travail de pigallery2
STORAGE_PHOTO="/tmp/share/photos"
WORKING_DIR=/tmp/.pigallery2
if [ -n "$STORAGE_LOCATION" ] && [ "$STORAGE_LOCATION" != "auto" ]; then
    STORAGE_PHOTO="$STORAGE_LOCATION/photos"
    WORKING_DIR="$STORAGE_LOCATION/.pigallery2"
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
            # Définir le répertoire de partage
            STORAGE_PHOTO="$FIRST_MOUNT/photos"
            WORKING_DIR="$FIRST_MOUNT/.pigallery2"
        else
            echo "Le disque $FIRST_MOUNT n'est pas accessible en écriture"
        fi
    fi
fi

echo "Répertoire de stockage Pigallery2 défini sur : $STORAGE_PHOTO"
echo "Répertoire de travail Pigallery2 défini sur : $WORKING_DIR"

echo "Préparation des répertoires Pigallery2..."
if [ ! -d "$STORAGE_PHOTO" ]; then
    echo "Création du répertoire de stockage Pigallery2 : $STORAGE_PHOTO"
    mkdir -p "$STORAGE_PHOTO"
    chown pigallery2:users "$STORAGE_PHOTO"
fi
chmod g+rw "$STORAGE_PHOTO"
setfacl -d -m g:users:rwX $STORAGE_PHOTO
if [ ! -d "$WORKING_DIR" ]; then
    echo "Création du répertoire de travail Pigallery2 : $WORKING_DIR"
    mkdir -p "$WORKING_DIR"
    chown pigallery2:users "$WORKING_DIR"
fi

echo "Configuration de Pigallery2 pour utiliser le répertoire de stockage personnalisé..."
CONFIG_FILE="/opt/pigallery2/config.json"
sed -i "s|%STORAGE_PHOTO%|$STORAGE_PHOTO|g" $CONFIG_FILE
sed -i "s|%WORKING_DIR%|$WORKING_DIR|g" $CONFIG_FILE

# Fix des permissions sur les répertoires
chown -R pigallery2:users /opt/pigallery2

# Démarre pigallery2 en tant qu'utilisateur pigallery2
cd /opt/pigallery2
runuser -u pigallery2 -g users -- npm start