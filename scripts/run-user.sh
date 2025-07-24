#!/bin/bash

# Script de création des utilisateurs

set -e


# Les utilisateurs sont définis dans un fichier de configuration
# Chaque ligne doit être au format USERn=login,password
# où n est un nombre entier (1, 2, 3, ...)
# Exemple :
#   USER1=user1,password1
#   USER2=user2,password2
CONFIG_FILE="/config.env"

# Vérifier que le fichier existe
[ -f "$CONFIG_FILE" ] || { echo "Fichier $CONFIG_FILE introuvable"; exit 1; }

# Charger les variables de configuration
source "$CONFIG_FILE"

# Récupérer toutes les variables d'environnement commençant par USER
vars=$(set | grep -E '^(USER[0-9]+)=' | cut -d= -f1)

for var in $vars; do
    val="${!var}"
    IFS=',' read -r login password <<< "$val"

    if [ -z "$login" ] || [ -z "$password" ]; then
        echo "Variable $var mal formatée, ignorée"
        continue
    fi


    echo "Ajout de l'utilisateur pour l'accès SSH : $login"
    /usr/local/bin/add-user-ssh.sh "$login" "$password"

    # Si docker samba en marche, alors le user et mot de passe dans le docker
    if docker ps -a | grep -q "samba"; then
        echo "Ajout de l'utilisateur $login dans Samba..."
        /usr/local/bin/add-user-samba.sh "$login" "$password"
    fi

        

done

