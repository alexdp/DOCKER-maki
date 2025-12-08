#!/bin/bash
set -e

# Charger la variable HOSTNAME du service précédent
if [ -f /run/config.env ]; then
    source /run/config.env
else
    echo "[load-network-config] /run/config.env introuvable, utilisation du hostname du système."
    HOSTNAME=$(hostname)
fi

# Vérification de la variable HOSTNAME
echo "Hostname défini sur : $HOSTNAME"

# Configuration du hostname système ===
hostnamectl set-hostname "$HOSTNAME"
echo "$HOSTNAME" > /etc/hostname
echo "127.0.1.1 $HOSTNAME" >> /etc/hosts

# Configuration réseau DHCP avec envoi du hostname ===
mkdir -p /etc/systemd/network
mkdir -p /etc/wpa_supplicant


# Détection de l'interface Wi-Fi
WIFI_IFACE=$(find /sys/class/net -maxdepth 1 -type l -exec basename {} \; | grep -E '^wl' | head -n1)
if [ -z "$WIFI_IFACE" ]; then
    echo "[load-network-config] Aucune interface Wi-Fi détectée."
fi
echo "[load-network-config] Interface Wi-Fi détectée : $WIFI_IFACE"



# Préparation du fichier de configuration WPA (et suppression si pas de Wi-Fi)
cat <<EOF > /etc/wpa_supplicant/wpa_supplicant-$WIFI_IFACE.conf
ctrl_interface=/run/wpa_supplicant
update_config=1
country=FR

network={
    ssid="$NETWORK_SSID"
    psk="$NETWORK_PSK"
}
EOF
if [ -z "$WIFI_IFACE" ]; then
    rm /etc/wpa_supplicant/wpa_supplicant-$WIFI_IFACE.conf
fi


# Préparation du fichier de service wpa_supplicant (et suppression si pas de Wi-Fi)
cat <<EOF > /etc/systemd/system/wpa_supplicant@$WIFI_IFACE.service
[Unit]
Description=WPA supplicant pour %i
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=simple
ExecStart=/sbin/wpa_supplicant -i %i -c /etc/wpa_supplicant/wpa_supplicant-%i.conf

[Install]
WantedBy=multi-user.target
EOF
if [ -z "$WIFI_IFACE" ]; then
    rm /etc/systemd/system/wpa_supplicant@$WIFI_IFACE.service
fi

# Identification de l'interface réseau à configurer
IFACE_MATCH="!lo"
if [ "$NETWORK_TYPE" = "wifi" ] && [ -n "$NETWORK_SSID" ] && [ -n "$NETWORK_PSK" ] && [ -n "$WIFI_IFACE" ]; then
    IFACE_MATCH="$WIFI_IFACE"
fi
if [ "$NETWORK_TYPE" != "wifi" ] && [ -n "$WIFI_IFACE" ]; then
    IFACE_MATCH="!wl*"
fi

# Forcage de l'interface réseau si précisé dans les variables d'environnement
if [ -n "$NETWORK_INTERFACE" ]; then
    IFACE_MATCH="$NETWORK_INTERFACE"
fi

# Préparation du fichier de configuration réseau DHCP (et suppression si mode statique)
cat <<EOF > /etc/systemd/network/20-dhcp.network
[Match]
Name=!lo
Name=$IFACE_MATCH

[Network]
DHCP=yes

[DHCP]
UseDNS=yes
SendHostname=yes
Hostname=$HOSTNAME
ClientIdentifier=mac
EOF

if [ "$NETWORK_DHCP" = "false" ]; then
    rm /etc/systemd/network/20-dhcp.network
fi


# Préparation du fichier de configuration réseau statique (et suppression si mode statique)
[ -z "$NETWORK_STATIC_DNS" ] && NETWORK_STATIC_DNS="$NETWORK_STATIC_GATEWAY"
if [ "$NETWORK_STATIC_NETMASK" = "255.255.255.0" ]; then NETWORK_STATIC_NETMASK="24"; fi
if [ "$NETWORK_STATIC_NETMASK" = "255.255.0.0" ]; then NETWORK_STATIC_NETMASK="16"; fi
if [ "$NETWORK_STATIC_NETMASK" = "255.0.0.0" ]; then NETWORK_STATIC_NETMASK="8"; fi
cat <<EOF > /etc/systemd/network/20-eth.network
[Match]
Name=!lo
Name=$IFACE_MATCH

[Network]
Address=$NETWORK_STATIC_ADDRESS/$NETWORK_STATIC_NETMASK
Gateway=$NETWORK_STATIC_GATEWAY
DNS=$NETWORK_STATIC_DNS
EOF

if [ "$NETWORK_DHCP" != "false" ]; then
    rm /etc/systemd/network/20-eth.network
fi


echo "Configuration terminée. Nom DNS envoyé : $HOSTNAME"


# Démarrer getty avec le nouveau hostname
systemctl enable getty@tty1.service
systemctl start getty@tty1.service


# Démarrer le service wpa_supplicant puis le client réseau DHCP ou statique si une interface Wi-Fi est détectée
if [ "$NETWORK_TYPE" = "wifi" ] && [ -n "$NETWORK_SSID" ] && [ -n "$NETWORK_PSK" ] && [ -n "$WIFI_IFACE" ]; then
    echo "[load-network-config] Démarrage de l'interface WIFI $WIFI_IFACE et du service réseau systemd-networkd"
    systemctl enable wpa_supplicant@$WIFI_IFACE.service
    systemctl enable systemd-networkd.service
    systemctl start systemd-networkd.service
    systemctl restart wpa_supplicant@$WIFI_IFACE.service
else 
# Démarrer le client réseau DHCP ou statique sur l'interface filaire ou autre interface détectée
    echo "[load-network-config] Démarrage du service DHCP systemd-networkd sur l'interface $IFACE_MATCH"
    systemctl enable systemd-networkd.service
    systemctl start systemd-networkd.service
fi



# Démarrer les services réseaux de resolution de nom et de propagation du nom DNS de la machine
systemctl enable systemd-resolved.service
systemctl enable avahi-daemon.service
systemctl start systemd-resolved.service
systemctl start avahi-daemon.service


