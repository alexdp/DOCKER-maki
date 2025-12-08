#!/bin/bash

set -e


# Charger les variables d'environnement depuis le config.env (generé par load-usb-config)
if [ -f /run/config.env ]; then
    source /run/config.env
fi

# Calcul du repertoire de travail de Kopia
WORKING_DIR=/tmp/.kopia
if [ -n "$STORAGE_LOCATION" ] && [ "$STORAGE_LOCATION" != "auto" ]; then
    WORKING_DIR="$STORAGE_LOCATION/.kopia"
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
            WORKING_DIR="$FIRST_MOUNT/.kopia"
        else
            echo "Le disque $FIRST_MOUNT n'est pas accessible en écriture"
        fi
    fi
fi


echo "Répertoire de travail Kopia défini sur : $WORKING_DIR"
if [ ! -d "$WORKING_DIR" ]; then
    echo "Création du répertoire de travail de Kopia : $WORKING_DIR"
    mkdir -p "$WORKING_DIR"
fi

export KOPIA_CONFIG_PATH=$WORKING_DIR/config
export KOPIA_CACHE_DIRECTORY=$WORKING_DIR/cache
export KOPIA_LOG_DIR=$WORKING_DIR/logs
export KOPIA_PASSWORD="password"

echo "Préparation du compte administrateur Kopia..."
source <(python3 /usr/local/bin/load-kopia-admin-user.py)


kopia server start --address=0.0.0.0:51515 --insecure