#!/bin/bash

# Partage public du dossier /shared-disk/public du premier disque dur trouvé

set -e

# Configuration pour partage public uniquement

# Créer le répertoire de logs s'il n'existe pas
mkdir -p /var/log/samba

# Trouver le premier disque dur (excluant les partitions loop et ram)
echo "Recherche du premier disque dur pour le partage Samba..."
FIRST_DISK=$(lsblk -nd -o NAME | grep -E '^(sd|hd|vd|nvme)' | head -1)

if [ -z "$FIRST_DISK" ]; then
    echo "ERREUR: Aucun disque dur trouvé, impossible de configurer le partage Samba"
    echo "$(date): ERREUR - Aucun disque dur trouvé pour le partage Samba" >> /var/log/samba/samba-setup.log
    echo "Le service Samba ne sera pas configuré."
    echo "Vérifiez qu'un disque dur est connecté et relancez le script."
    echo "Continuation du démarrage système..."
    return 1 2>/dev/null || exit 1
fi

echo "Premier disque trouvé: $FIRST_DISK"

# Déterminer la première partition du premier disque pour le partage Samba
if [ -e "/dev/${FIRST_DISK}1" ]; then
    SAMBA_DEVICE="/dev/${FIRST_DISK}1"
else
    SAMBA_DEVICE="/dev/${FIRST_DISK}"
fi

SAMBA_DEV_NAME=$(basename "$SAMBA_DEVICE")
SAMBA_MOUNT_POINT="/mnt/${SAMBA_DEV_NAME}"

echo "Partition/disque pour Samba: $SAMBA_DEVICE"
echo "Point de montage attendu: $SAMBA_MOUNT_POINT"

# Vérifier que la partition est montée (montage fait par run-mount.sh)
if mountpoint -q "$SAMBA_MOUNT_POINT"; then
    echo "✓ Partition $SAMBA_DEVICE est montée sur $SAMBA_MOUNT_POINT"
    
    # Créer le dossier public avec les bonnes permissions
    mkdir -p "$SAMBA_MOUNT_POINT/shared-disk/public"
    
    # Configurer les permissions pour le partage de fichiers
    chown smbuser:smbuser "$SAMBA_MOUNT_POINT/shared-disk/public"
    chmod 0777 "$SAMBA_MOUNT_POINT/shared-disk/public"
  
    PUBLIC_PATH="$SAMBA_MOUNT_POINT/shared-disk/public"
    echo "✓ Dossier public configuré: $PUBLIC_PATH"
    echo "$(date): INFO - Partage Samba configuré sur $PUBLIC_PATH" >> /var/log/samba/samba-setup.log
else
    echo "ERREUR: La partition $SAMBA_DEVICE n'est pas montée sur $SAMBA_MOUNT_POINT"
    echo "Vérifiez que le script run-mount.sh a été exécuté avant run-samba.sh"
    echo "$(date): ERREUR - Partition Samba non montée" >> /var/log/samba/samba-setup.log
    echo "Continuation du démarrage système sans partage Samba..."
    return 1 2>/dev/null || exit 1
fi

# Sauvegarder la configuration Samba originale
cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

# Créer la configuration Samba pour tous les utilisateurs Linux
cat > /etc/samba/smb.conf << EOF
[global]
   workgroup = WORKGROUP
   server string = Linux Users Samba Server
   netbios name = linux-samba
   security = user
   passdb backend = tdbsam
   
[public]
   comment = Public Share - Linux Users Only
   path = $PUBLIC_PATH
   browsable = yes
   writable = yes
   guest ok = no
   read only = no
   create mask = 0666
   create directory = 0777
   force user = smbuser
EOF


# Tester la configuration Samba
echo "Test de la configuration Samba..."
testparm -s /etc/samba/smb.conf



# Redémarrer et activer les services Samba
systemctl restart smbd
systemctl restart nmbd

# Attendre que les services démarrent
sleep 3


# Configurer le firewall pour autoriser Samba (si ufw est installé)
if command -v ufw &> /dev/null; then
    ufw allow samba
fi

