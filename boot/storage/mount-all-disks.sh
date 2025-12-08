#!/bin/bash

# Script pour monter toutes les partitions de tous les disques



# Créer le répertoire de logs s'il n'existe pas
mkdir -p /var/log/mount

echo "=== Montage automatique de toutes les partitions ==="
echo "$(date): Début du montage automatique" >> /var/log/mount/mount-setup.log

# Identifier le disque de boot (celui qui contient la racine /)
# Pour un système live, on évite de filtrer par disque de boot car c'est complexe
# On va plutôt monter tous les disques et exclure ceux qui sont déjà utilisés
echo "Mode système live détecté, montage de tous les disques disponibles"

# Trouver tous les disques (excluant les partitions loop, ram)
ALL_DISKS=$(lsblk -nd -o NAME | grep -E '^(sd|hd|vd|nvme)')

if [ -z "$ALL_DISKS" ]; then
    echo "ATTENTION: Aucun disque dur trouvé"
    echo "$(date): ATTENTION - Aucun disque dur trouvé" >> /var/log/mount/mount-setup.log
    exit 0
fi

echo "Disques détectés: $ALL_DISKS"

# Monter TOUTES les partitions de TOUS les disques
for DISK in $ALL_DISKS; do
    echo "Traitement du disque: $DISK"
    
    # Trouver toutes les partitions de ce disque
    PARTITIONS=$(lsblk -ln -o NAME "/dev/$DISK" | grep -v "^$DISK$" | sed "s/^/\/dev\//")
    
    if [ -z "$PARTITIONS" ]; then
        # Pas de partitions, essayer de monter le disque entier
        echo "Tentative de montage du disque entier: /dev/$DISK"
        DEVICE="/dev/$DISK"
        DEV_NAME=$(basename "$DEVICE")
        MOUNT_POINT="/mnt/${DEV_NAME}"
        
        mkdir -p "$MOUNT_POINT"
        
        if ! mountpoint -q "$MOUNT_POINT"; then
            if mount "$DEVICE" "$MOUNT_POINT" 2>/dev/null; then
                echo "✓ Disque $DEVICE monté sur $MOUNT_POINT"
                echo "$(date): INFO - Disque $DEVICE monté sur $MOUNT_POINT" >> /var/log/mount/mount-setup.log
                
                # Ajouter au fstab si pas déjà présent
                if ! grep -q "$DEVICE.*$MOUNT_POINT" /etc/fstab; then
                    echo "$DEVICE $MOUNT_POINT auto defaults,nofail 0 2" >> /etc/fstab
                    echo "$(date): INFO - Entrée fstab ajoutée pour $DEVICE" >> /var/log/mount/mount-setup.log
                fi
            else
                echo "✗ Impossible de monter $DEVICE"
                echo "$(date): ERREUR - Impossible de monter $DEVICE" >> /var/log/mount/mount-setup.log
            fi
        else
            echo "✓ Disque $DEVICE déjà monté sur $MOUNT_POINT"
        fi
    else
        # Monter chaque partition
        for PARTITION in $PARTITIONS; do
            echo "Tentative de montage de la partition: $PARTITION"
            PART_NAME=$(basename "$PARTITION")
            MOUNT_POINT="/mnt/${PART_NAME}"
            
            mkdir -p "$MOUNT_POINT"
            
            if ! mountpoint -q "$MOUNT_POINT"; then
                if mount "$PARTITION" "$MOUNT_POINT" 2>/dev/null; then
                    echo "✓ Partition $PARTITION montée sur $MOUNT_POINT"
                    echo "$(date): INFO - Partition $PARTITION montée sur $MOUNT_POINT" >> /var/log/mount/mount-setup.log
                    
                    # Ajouter au fstab si pas déjà présent
                    if ! grep -q "$PARTITION.*$MOUNT_POINT" /etc/fstab; then
                        echo "$PARTITION $MOUNT_POINT auto defaults,nofail 0 2" >> /etc/fstab
                        echo "$(date): INFO - Entrée fstab ajoutée pour $PARTITION" >> /var/log/mount/mount-setup.log
                    fi
                else
                    echo "✗ Impossible de monter $PARTITION"
                    echo "$(date): ERREUR - Impossible de monter $PARTITION" >> /var/log/mount/mount-setup.log
                fi
            else
                echo "✓ Partition $PARTITION déjà montée sur $MOUNT_POINT"
            fi
        done
    fi
done

# Afficher un résumé des montages
echo ""
echo "=== Résumé des montages ==="
echo "Toutes les partitions montées dans /mnt/ :"
mount | grep "^/dev/" | grep "/mnt/" | while read line; do
    echo "  $line"
done

echo ""
echo "$(date): Fin du montage automatique" >> /var/log/mount/mount-setup.log
echo "✓ Montage automatique terminé - Consultez /var/log/mount/mount-setup.log pour les détails"
