#!/bin/bash

# Script pour charger les cartes du portail depuis le config.json

set -e

if [ ! -f /run/config.json ]; then
    echo "/run/config.json not found, creating empty portal-cards.json"
    echo "[]" > /var/www/html/portal-cards.json
    exit 0
fi

# Extrait .portal.cards dans portal-cards.json, ou crée un tableau vide en cas d'erreur
if ! jq '.portal.cards' /run/config.json > /var/www/html/portal-cards.json 2>/dev/null; then
    echo "[]" > /var/www/html/portal-cards.json
fi
