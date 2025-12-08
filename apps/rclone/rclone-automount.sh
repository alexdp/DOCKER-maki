#!/bin/bash
set -e

# Catch systemd stop/restart and unmount everything cleanly
trap 'echo "SIGTERM reçu : démontage de tous les remotes..."; umount_all; exit 0' TERM


# Vérifie que inotifywait est installé
command -v inotifywait >/dev/null 2>&1 || { echo >&2 "inotifywait n'est pas installé. Installer inotify-tools."; exit 1; }


# Vérifie que les variables d'environnement RClone sont définies (dans /etc/environment par load-rclone-config)
if [ -z "$RCLONE_CONFIG" ] || [ -z "$RCLONE_BASE_MOUNT_DIR" ]; then
    echo "Les variables d'environnement RCLONE_* ne sont pas définies. Vérifiez le chargement du service load-rclone-config."
    exit 1
fi


# Timeout pour le démontage en secondes
UMOUNT_TIMEOUT=10

# Vérifie que inotifywait est installé
command -v inotifywait >/dev/null 2>&1 || { echo >&2 "inotifywait n'est pas installé. Installe inotify-tools."; exit 1; }

# Fonction pour lister les remotes dans la config rclone.conf
list_remotes() {
    rclone listremotes 2>/dev/null | sed 's/:$//'
}

# Fonction pour lister les remotes actuellement montés
list_mounted_remotes() {
    for dir in "$RCLONE_BASE_MOUNT_DIR"/*; do
        [ -d "$dir" ] || continue
        if mountpoint -q "$dir"; then
            basename "$dir"
        fi
    done
}

# Monter un remote
mount_remote() {
    local remote="$1"
    local mountpoint="$RCLONE_BASE_MOUNT_DIR/$remote"

    # Création du point de montage s'il n'existe pas
    if [ ! -d "$mountpoint" ]; then
        mkdir -p "$mountpoint"
        echo "Création du point de montage $mountpoint"
        chown rclone:users "$mountpoint"
    fi
    chmod 770 "$mountpoint"

    # Vérifie si déjà monté
    if mountpoint -q "$mountpoint"; then
        echo "$remote déjà monté sur $mountpoint"
        return
    fi

    echo "Montage de $remote sur $mountpoint"
    # Lance le montage en background (rclone mount doit rester actif)
    runuser -u rclone -g users -- /bin/bash -c "
        source /etc/environment
        rclone mount \"$remote:\" \"$mountpoint\" --daemon
    "
}

# Démontage d'un remote
umount_remote() {
    local remote="$1"
    local mountpoint="$RCLONE_BASE_MOUNT_DIR/$remote"

    # Vérifie si monté
    if mountpoint -q "$mountpoint"; then
        echo "Démontage de $remote de $mountpoint"
        fusermount -uz "$mountpoint" || umount "$mountpoint" || {
            echo "Échec du démontage de $mountpoint"
            return 1
        }
    else
        echo "$remote n'est pas monté"
    fi

    # Vérifie que le dossier existe avant suppression
    if [ ! -d "$mountpoint" ]; then
        return 0
    fi

    # Supprime uniquement si vide
    if [ -z "$(ls -A "$mountpoint")" ]; then
        echo "Suppression du dossier vide $mountpoint"
        rmdir "$mountpoint"
    else
        echo "Le dossier $mountpoint n'est pas vide, suppression annulée."
    fi
}

# Monter tous les remotes
mount_all() {
    local remotes
    remotes=$(list_remotes)
    for remote in $remotes; do
        mount_remote "$remote"
    done
    echo "Tous les remotes ont été montés. Le script reste actif pour gérer les signaux."
    sleep infinity
}

# Démontage de tous les remotes
umount_all() {
    local mounted remotedir

    echo "Démontage de tous les remotes montés..."

    # 1. Démontage de tout ce qui est monté
    mounted=$(list_mounted_remotes)
    for remote in $mounted; do
        umount_remote "$remote"
    done

    echo "Nettoyage des dossiers vides dans $RCLONE_BASE_MOUNT_DIR..."

    # 2. Suppression des dossiers vides restants, sans risquer de supprimer un point monté
    for remotedir in "$RCLONE_BASE_MOUNT_DIR"/*; do
        [ -d "$remotedir" ] || continue

        # Si toujours monté → on touche pas
        if mountpoint -q "$remotedir"; then
            continue
        fi

        # Dossier vide → suppression safe
        if [ -z "$(ls -A "$remotedir")" ]; then
            echo "Suppression du dossier vide $(basename "$remotedir")"
            rmdir "$remotedir"
        fi
    done
}


# Montage initial
umount_all
mount_all

