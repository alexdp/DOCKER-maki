#!/usr/bin/env python3
"""
create-samba-only.py
---------------------
Crée ou met à jour les comptes Samba4 d'après un fichier JSON (/run/config.json par défaut).
Les comptes Linux doivent déjà exister.
"""

import json
import subprocess
import sys
from pathlib import Path

DEFAULT_CONFIG = "/run/config.json"

def run(cmd, input_text=None, check=True):
    print(f"[run] {' '.join(cmd)}")
    return subprocess.run(cmd, input=input_text, text=True, check=check)

def user_exists_linux(name: str) -> bool:
    """Vérifie que l'utilisateur existe dans /etc/passwd"""
    return subprocess.run(["getent", "passwd", name], check=False).returncode == 0

def add_or_update_samba_user(username: str, password: str | None):
    """Ajoute ou met à jour un utilisateur Samba avec mot de passe optionnel."""
    if not user_exists_linux(username):
        print(f"[skip] utilisateur système '{username}' inexistant — ignoré.")
        return

    if not password:
        print(f"[skip] utilisateur '{username}' sans mot de passe Samba — ignoré.")
        return

    # smbpasswd -a : ajout si absent, -s : silencieux (pas d'interaction)
    input_data = f"{password}\n{password}\n"
    try:
        run(["smbpasswd", "-a", "-s", username], input_text=input_data)
        print(f"[ok] utilisateur Samba '{username}' ajouté/mis à jour.")
    except subprocess.CalledProcessError as e:
        print(f"[error] échec pour {username}: {e}")

def load_config(path: str):
    p = Path(path)
    if not p.exists():
        raise SystemExit(f"Config introuvable: {path}")
    return json.loads(p.read_text(encoding="utf-8"))

def main():
    import os
    if os.getuid() != 0:
        print("ERREUR: exécuter ce script en root.")
        sys.exit(1)

    cfg_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CONFIG
    cfg = load_config(cfg_path)

    users = cfg.get("users", [])
    if not users:
        print("[warning] aucun utilisateur dans la configuration.")
        return

    for u in users:
        name = u.get("name")
        password = u.get("password")

        if not name:
            print(f"[skip] entrée invalide: {u}")
            continue

        add_or_update_samba_user(name, password)

if __name__ == "__main__":
    main()