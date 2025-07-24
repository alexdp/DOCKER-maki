#!/bin/sh

# Vérification des paramètres
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <username> <password>"
  exit 1
fi

USERNAME="$1"
PASSWORD="$2"
CONTAINER="samba"

echo "Vérification de l'existence de l'utilisateur Linux : $USERNAME"

docker exec "$CONTAINER" id "$USERNAME" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Utilisateur Linux introuvable, création..."
  docker exec "$CONTAINER" useradd -M -s /sbin/nologin "$USERNAME"
else
  echo "Utilisateur Linux déjà existant."
fi

echo "Ajout ou mise à jour du mot de passe Samba pour $USERNAME"

printf "%s\n%s\n" "$PASSWORD" "$PASSWORD" | docker exec -i "$CONTAINER" smbpasswd -s -a "$USERNAME"

echo "Utilisateur Samba prêt : $USERNAME"
