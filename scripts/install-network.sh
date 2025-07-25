#!/bin/bash

# Configuration réseau avec hostname "nas"

DEBIAN_FRONTEND=noninteractive
apt update && apt install -y systemd-networkd systemd-resolved isc-dhcp-client || true
apt install -y iproute2 iputils-ping net-tools dnsutils traceroute curl wget || true


# Configuration du réseau en DHCP
mkdir -p /etc/systemd/network
cat <<EOF > /etc/systemd/network/20-dhcp.network
[Match]
Name=!lo

[Network]
DHCP=yes
EOF

# Configuration DNS 
echo "Configuration DNS..."
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
systemctl enable systemd-networkd
systemctl enable systemd-resolved

echo "Configuration réseau terminée"

