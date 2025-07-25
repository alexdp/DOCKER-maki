#!/bin/bash

# Script pour gérer les copies et mirroir de données

CONFIG_FILE="$ROOT_DIR/config.env"
# Charger les variables de configuration
if  [ -f "$CONFIG_FILE" ]; then
    dos2unix "$CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "Fichier $CONFIG_FILE introuvable. Aucun utilisateur ne sera créé."
fi

BACKUP_SCRIPT="/usr/local/bin/backup"
mkdir -p "$(dirname "$BACKUP_SCRIPT")"

# Ecris un script backup.sh dans /usr/local/bin/backup qui indique que les répertoires source ou de destination ne sont pas définis et que la sauvegarde ne sera pas effectuée
cat > "$BACKUP_SCRIPT" << EOF
#!/bin/bash
# Script de sauvegarde pour synchroniser $ROOT_DIR avec $MIRROR_DIR
echo "Les répertoires source ou de destination ne sont pas définis. Aucune sauvegarde effectuée."
EOF
chmod +x "$BACKUP_SCRIPT"


# Si $ROOT_DIR n'est pas défini, alors on ne fait rien
if [ -z "$ROOT_DIR" ]; then
    echo "La variable ROOT_DIR n'est pas définie. Aucune action effectuée."
    exit 0
fi


# Si $MIRROR_DIR=none, alors on ne fait rien
if [ "$MIRROR_DIR" == "none" ]; then
    echo "Aucun répertoire de miroir spécifié. Aucune action effectuée."
    exit 0
fi

# Vérifier si le répertoire de miroir accessible en lecture/écriture
if [ ! -d "$MIRROR_DIR" ]; then
    echo "Le répertoire de miroir $MIRROR_DIR n'existe pas. Aucune action effectuée."
    exit 0
fi


# Mettre en place un crontab avec un rsync entre $ROOT_DIR et $MIRROR_DIR
# Ecrase le script dans /usr/local/bin/backup avec le script de sauvegarde
cat > "$BACKUP_SCRIPT" << EOF
#!/bin/bash
# Script de sauvegarde pour synchroniser $ROOT_DIR avec $MIRROR_DIR
set -e
if [ -d "$ROOT_DIR" ] && [ -d "$MIRROR_DIR" ]; then
    rsync -av --delete "$ROOT_DIR/" "$MIRROR_DIR/" > /var/log/backup.log 2>&1
else
    echo "Les répertoires $ROOT_DIR ou $MIRROR_DIR n'existent pas. Aucune action effectuée." >> /var/log/backup.log
fi
EOF
chmod +x "$BACKUP_SCRIPT"


# Ajouter le script backup.sh au crontab pour s'exécuter une fois par semaine à 2h du matin en root
echo "0 2 * * 0 root /usr/local/bin/backup > /var/log/backup.log 2>&1" >> /etc/crontab


