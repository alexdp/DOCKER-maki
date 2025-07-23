#!/bin/sh

# Vérification des paramètres
if [ "$#" -lt 4 ]; then
  echo "Usage: $0 <email> <password> <first_name> <last_name> [--admin]"
  exit 1
fi

# Paramètres positionnels
EMAIL="$1"
PASSWORD="$2"
FIRSTNAME="$3"
LASTNAME="$4"
IS_ADMIN=false

# Optionnel : --admin
if [ "$5" = "--admin" ]; then
  IS_ADMIN=true
fi

CONTAINER="immich"

echo "🔍 Vérification de l'existence de l'utilisateur Immich : $EMAIL"

USER_EXISTS=$(docker exec "$CONTAINER" \
  npx prisma --schema /usr/src/app/prisma/schema.prisma \
  db execute --stdin <<EOF | grep -c "$EMAIL"
SELECT email FROM users WHERE email = '$EMAIL';
EOF
)

if [ "$USER_EXISTS" -eq 0 ]; then
  echo "✅ Utilisateur non trouvé, création..."
  docker exec "$CONTAINER" npx nestjs-command create-user \
    --email "$EMAIL" \
    --password "$PASSWORD" \
    --first-name "$FIRSTNAME" \
    --last-name "$LASTNAME" \
    $( [ "$IS_ADMIN" = true ] && echo "--admin true" )
else
  echo "✔️ Utilisateur déjà existant : $EMAIL"
fi
