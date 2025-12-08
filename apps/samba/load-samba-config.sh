#!/bin/bash
set -e


# Charger la variable STORAGE_SHARE du service load-usb-config
if [ -f /run/config.env ]; then
    source /run/config.env
fi


# Définition de STORAGE_SHARE en s'appuyant sur STORAGE_LOCATION ou, par défaut, /tmp/share
STORAGE_SHARE="/tmp/share"
if [ -n "$STORAGE_LOCATION" ] && [ "$STORAGE_LOCATION" != "auto" ]; then
    STORAGE_SHARE="$STORAGE_LOCATION"
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
            STORAGE_SHARE="$FIRST_MOUNT"
        else
            echo "Le disque $FIRST_MOUNT n'est pas accessible en écriture"
        fi
    fi
fi

echo "Répertoire de partage Samba défini sur : $STORAGE_SHARE"

# Modifie le smb.conf pour remplacer path = /mnt par le bon répertoire
sed -i "s|path\\s*=\\s*/mnt|path = $STORAGE_SHARE|g" /etc/samba/smb.conf
