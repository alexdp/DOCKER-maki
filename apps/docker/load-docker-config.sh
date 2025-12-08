#!/bin/bash
set -e

# Charger la variable HOSTNAME du service précédent
if [ -f /run/config.env ]; then
    source /run/config.env
fi


# Détection du répertoire de travail de Docker (stockage des volumes, images, etc.)
STORAGE_DOCKER="/var/lib/docker"
if [ -n "$STORAGE_LOCATION" ] && [ "$STORAGE_LOCATION" != "auto" ]; then
    STORAGE_DOCKER="$STORAGE_LOCATION/.docker"
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
            # Définir le répertoire de stockage Jellyfin
            STORAGE_DOCKER="$FIRST_MOUNT/.docker"
        else
            echo "Le disque $FIRST_MOUNT n'est pas accessible en écriture"
        fi
    fi
fi

echo "Répertoire de stockage Docker défini sur : $STORAGE_DOCKER"

mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "ipv6": false,
  "ip6tables": false,
  "bridge": "none",
  "data-root": "$STORAGE_DOCKER"
}
EOF

if [ ! -d "$STORAGE_DOCKER" ]; then
    echo "Création du répertoire de stockage Docker : $STORAGE_DOCKER"
    mkdir -p "$STORAGE_DOCKER"    
fi
chmod 700 "$STORAGE_DOCKER"