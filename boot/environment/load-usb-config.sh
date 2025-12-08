#!/bin/bash
set -e

SOURCE_JSON_CONFIG_FILE="/cdrom/config.json"
RUNTIME_JSON_CONFIG_FILE="/run/config.json"
RUNTIME_ENV="/run/config.env"
GLOBAL_ENV="/etc/environment"


for i in {1..10}; do
    [ -f "$SOURCE_JSON_CONFIG_FILE" ] && break
    sleep 1
done

[ -f "$SOURCE_JSON_CONFIG_FILE" ] || exit 0


echo "Loading USB config: $SOURCE_JSON_CONFIG_FILE"

# Copie dans /run (pour les services systemd)
cp "$SOURCE_JSON_CONFIG_FILE" "$RUNTIME_JSON_CONFIG_FILE"
dos2unix "$RUNTIME_JSON_CONFIG_FILE"
chmod 600 "$RUNTIME_JSON_CONFIG_FILE"

# Extraction des variables d'environnement depuis le fichier JSON
# (Retire les variables qui ont PASSWORD dans leur nom pour des raisons de sécurité)
jq -r '
  paths(scalars) as $p |
  ($p | map(tostring) | join("_") | ascii_upcase) +
  "=" +
  (getpath($p) | @sh)
' "$RUNTIME_JSON_CONFIG_FILE" | grep -v 'PASSWORD' > "$RUNTIME_ENV"


# Ajouter le contenu de /run/config.env à /etc/environment
# sans écraser ce qui existe déjà
cat "$RUNTIME_ENV" >> "$GLOBAL_ENV"
chmod 644 "$GLOBAL_ENV"

echo "Configuration imported into /etc/environment"
echo "USB configuration loading completed."