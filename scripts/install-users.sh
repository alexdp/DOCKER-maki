#!/bin/bash

# Script de création d'utilisateurs dans le chroot

set -e

# Ajoute le user admin/password (avec permissions sudo)
adduser --disabled-password --gecos "" admin
echo "admin:password" | chpasswd
#(sleep 1; echo "password"; sleep 1; echo "password") | smbpasswd -s -a "admin"
echo 'admin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers



