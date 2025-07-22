#!/bin/bash

# Installation et configuration du service SSH

echo "Installation du serveur SSH..."
apt update && apt install -y openssh-server || true

# Sauvegarder la configuration SSH originale
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Configuration SSH sécurisée
echo "Configuration du service SSH..."
cat > /etc/ssh/sshd_config << 'EOF'
# Configuration SSH pour NAS Ubuntu Live
Port 22
Protocol 2

# Authentification
PermitRootLogin no
PasswordAuthentication yes

# Sécurité
MaxAuthTries 3
MaxSessions 10
ClientAliveInterval 300
ClientAliveCountMax 2

# Restrictions réseau
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# Logging
SyslogFacility AUTH
LogLevel INFO

# Subsystèmes
Subsystem sftp /usr/lib/openssh/sftp-server


# Autres options de sécurité
X11Forwarding yes
AllowTcpForwarding yes
GatewayPorts no
PermitTunnel no
EOF


# Activer et démarrer le service SSH
echo "Activation du service SSH..."
systemctl enable ssh
systemctl enable sshd

# Configurer le firewall pour SSH (si ufw est installé)
if command -v ufw >/dev/null 2>&1; then
    echo "Configuration du firewall pour SSH..."
    ufw allow ssh
    ufw allow 22/tcp
fi


