#!/bin/bash

# Configurer le hostname
echo "Configuration du hostname..."

# Charger les variables de configuration contenant le nom d'hôte
CONFIG_FILE="$ROOT_DIR/config.env"
if  [ -f "$CONFIG_FILE" ]; then
    dos2unix "$CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "Fichier $CONFIG_FILE introuvable, utilisation du nom d'hôte par défaut 'maki'."
    HOSTNAME="maki"
fi


# Interface(s) à configurer
INTERFACES=$(ip -o link show | awk -F': ' '/state UP/ && !/lo/ {print $2}')

# Définir le hostname système
echo "$HOSTNAME" > /etc/hostname
hostnamectl set-hostname "$HOSTNAME"

# Configuration du client DHCP
cat > /etc/dhcp/dhclient.conf <<EOF
send host-name "$HOSTNAME";
request subnet-mask, broadcast-address, time-offset, routers,
        domain-name, domain-name-servers, host-name;
EOF


# Lancer dhclient pour chaque interface réseau active
for IFACE in $INTERFACES; do
    echo "===> Configuring $IFACE"
    dhclient -v -cf /etc/dhcp/dhclient.conf "$IFACE"
done