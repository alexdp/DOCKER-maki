import json
import os

# Recherche le premier utilisateur admin dans le fichier de configuration pour le positionner en tant qu'admin Kopia
# via les variables d'environnement KOPIA_SERVER_USERNAME et KOPIA_SERVER_PASSWORD


CONFIG_FILE = "/run/config.json"

def load_admin_credentials():
    # Charger le fichier JSON
    with open(CONFIG_FILE, "r") as f:
        data = json.load(f)

    # Parcourir la liste des utilisateurs
    users = data.get("users", [])
    for user in users:
        if user.get("admin") is True and "name" in user and "password" in user:
            return user["name"], user["password"]

    # Aucun utilisateur admin valide trouvé
    return "admin", "password"


def set_kopia_env():
    username, password = load_admin_credentials()

    # Génération exportable
    print(f'export KOPIA_SERVER_USERNAME="{username}"')
    print(f'export KOPIA_SERVER_PASSWORD="{password}"')


if __name__ == "__main__":
    set_kopia_env()
