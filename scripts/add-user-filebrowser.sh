#!/bin/sh

# Vérification des paramètres
if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <username> <password> <scope_path> [--admin]"
  exit 1
fi

USERNAME="$1"
PASSWORD="$2"
SCOPE="$3"
IS_ADMIN=false
CONTAINER="filebrowser"

if [ "$4" = "--admin" ]; then
  IS_ADMIN=true
fi

echo "🔍 Vérification de l'existence de l'utilisateur FileBrowser : $USERNAME"

USER_EXISTS=$(docker exec "$CONTAINER" filebrowser users list | grep -c "^$USERNAME\b")

if [ "$USER_EXISTS" -eq 0 ]; then
  echo "✅ Utilisateur non trouvé, création..."
  docker exec "$CONTAINER" filebrowser users add "$USERNAME" "$PASSWORD" \
    --scope "$SCOPE" \
    $( [ "$IS_ADMIN" = true ] && echo "--perm.admin=true" )
else
  echo "✔️ Utilisateur déjà existant : $USERNAME"
fi
