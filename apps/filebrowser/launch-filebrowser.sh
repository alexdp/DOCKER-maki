#!/bin/bash
set -e

FILEBROWSER_DB="/etc/filebrowser/filebrowser.db"

# Charger la variable FILEBROWSER_ROOT du service load-usb-config
if [ -f /run/config.env ]; then
    source /run/config.env
fi

# Création de l'utilisateur filebrowser s'il n'existe pas
id -u filebrowser &>/dev/null || useradd -r -s /usr/sbin/nologin filebrowser
# Ajouter l'utilisateur filebrowser au groupe users pour accéder aux disques montés
usermod -aG users filebrowser

# Définition de STORAGE_SHARE en s'appuyant sur STORAGE_LOCATION ou, par défaut, /tmp/share
STORAGE_SHARE="/tmp/share"
WORKING_DIR="/tmp/filebrowser"
if [ -n "$STORAGE_LOCATION" ] && [ "$STORAGE_LOCATION" != "auto" ]; then
    STORAGE_SHARE="$STORAGE_LOCATION"
    WORKING_DIR="$STORAGE_LOCATION/.filebrowser"
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
            WORKING_DIR="$FIRST_MOUNT/.filebrowser"
        else
            echo "Le disque $FIRST_MOUNT n'est pas accessible en écriture"
        fi
    fi
fi

echo "Répertoire de racine pour Filebrowser défini sur : $STORAGE_SHARE"

echo "Répertoire de travail pour Filebrowser défini sur : $WORKING_DIR"
if [ ! -d "$WORKING_DIR" ]; then
    echo "Création du répertoire de travail pour Filebrowser : $WORKING_DIR"
    mkdir -p "$WORKING_DIR"
fi
chown -R filebrowser:users "$WORKING_DIR"

# Corriger les permissions sur la racine de filebrowser
chown filebrowser:users "$STORAGE_SHARE"
chmod g+rw "$STORAGE_SHARE"
setfacl -d -m g:users:rwX $STORAGE_SHARE
# Supprimer l'ancien fichier de base de données s'il existe
if [ -f "$FILEBROWSER_DB" ]; then
    rm -f "$FILEBROWSER_DB"
fi
# Charger la configuration et les utilisateurs de filebrowser
/usr/local/bin/filebrowser config init \
  --perm.admin=false \
  --perm.share=false \
  --file-mode "0o664" \
  --dir-mode "0o775" \
  --hideDotfiles=true \
  --cache-dir "$WORKING_DIR/cache" \
  --disable-preview-resize \
  --disable-thumbnails \
  --disable-type-detection-by-header \
  --auth.method=noauth \
  --minimum-password-length 2 \
  --address 127.0.0.1 \
  --port 8080 \
  --baseurl "/files" \
  --root "$STORAGE_SHARE" \
  --database "$FILEBROWSER_DB"
# Création de l'utilisateur filebrowser avec mot de passe car auth.method=noauth s'appuie sur l'existence d'un utilisateur
/usr/local/bin/filebrowser users add filebrowser Htre245hba! --database "$FILEBROWSER_DB"
# Donner les droits en lecture/écriture à l'utilisateur filebrowser sur la base de données
chmod 666 "$FILEBROWSER_DB"
# Démarrer filebrowser en tant qu'utilisateur filebrowser
runuser -u filebrowser -g users -- /usr/local/bin/filebrowser --database "$FILEBROWSER_DB"