#!/bin/bash

# Script de création des utilisateurs

set -e


# Les utilisateurs sont définis dans un fichier de configuration
# Chaque ligne doit être au format USERn=email,login,password,firstName,lastName
# où n est un nombre entier (1, 2, 3, ...)
# Exemple :
#   USER1=example1@example.com,user1,password1,firstname1,lastName1
#   USER2=example2@example.com,user2,password2,firstname2,lastName2
CONFIG_FILE="/config.env"

# Vérifier que le fichier existe
[ -f "$CONFIG_FILE" ] || { echo "Fichier $CONFIG_FILE introuvable"; exit 1; }

# Charger les variables de configuration
source "$CONFIG_FILE"

# Récupérer toutes les variables d'environnement commençant par USER
vars=$(env | grep -E '^(USER[0-9]+)=' | cut -d= -f1)

for var in $vars; do
    val="${!var}"
    IFS=',' read -r email login password firstName lastName <<< "$val"

    if [ -z "$login" ] || [ -z "$password" ]; then
        echo "⚠️  Variable $var mal formatée, ignorée"
        continue
    fi

    if id "$login" &>/dev/null; then
        echo "🔹 Utilisateur $login existe déjà"
    else
        echo "➕ Création de l'utilisateur $login ($email)..."
        useradd -m -s /bin/bash "$login"
        echo "$login:$password" | chpasswd
        echo "⚙️  Ajout de $login au groupe sudo"
        usermod -aG sudo "$login"
        echo "$login ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
        echo "✅ Utilisateur $login créé avec succès"


        # Si docker samba en marche, alors le user et mot de passe dans le docker
        if docker ps -a | grep -q "samba"; then
            echo "🔄 Ajout de l'utilisateur $login dans Samba..."
            /usr/local/bin/add-user-samba.sh "$login" "$password"
        fi

        # Si docker filebrowser en marche, alors le user et mot de passe dans le docker
        if docker ps -a | grep -q "filebrowser"; then
            echo "🔄 Ajout de l'utilisateur $login dans File Browser..."
            /usr/local/bin/add-user-filebrowser.sh "$login" "$password" "$ROOT_DIR"
        fi

        # Si docker immich en marche, alors le user et mot de passe dans le docker
        if docker ps -a | grep -q "immich"; then
            echo "🔄 Ajout de l'utilisateur $login dans Immich..."
            /usr/local/bin/add-user-immich.sh "$email" "$password" "$firstName" "$lastName"
            if [ "$login" = "alexdp" ]; then
                /usr/local/bin/add-user-immich.sh "$email" "$password" "$firstName" "$lastName" --admin
            fi
        fi
    fi
        

done

