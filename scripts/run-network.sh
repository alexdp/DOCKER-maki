#!/bin/bash

# Configurer le hostname
echo "Configuration du hostname..."

# Nom d'hôte à envoyer
HOSTNAME="nas"

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