#!/bin/sh

# Vérification des paramètres
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <username> <password>"
  exit 1
fi

USERNAME="$1"
PASSWORD="$2"

if getent passwd "$USERNAME" >/dev/null; then
  echo "Utilisateur $USERNAME existe déjà"
  echo "Ajout de $USERNAME au groupe sudo"
  usermod -aG sudo "$USERNAME"
  echo "$USERNAME:$PASSWORD" | chpasswd
  echo "Mot de passe de l'utilisateur $USERNAME mis à jour"
else
  echo "Création de l'utilisateur $USERNAME..."
  useradd -m -s /bin/bash "$USERNAME"
  echo "$USERNAME:$PASSWORD" | chpasswd
  echo "Ajout de $USERNAME au groupe sudo"
  usermod -aG sudo "$USERNAME"
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
  echo "Utilisateur $USERNAME créé avec succès"
fi
