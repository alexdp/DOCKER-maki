#!/usr/bin/env python3
"""
create-users-linux.py
Crée les comptes et groupes Linux à partir d’un fichier JSON (/run/config.json par défaut)
avec des UID/GID stables basés sur stable_id().
"""

import json
import subprocess
import sys
import hashlib
from pathlib import Path
import grp
import pwd

DEFAULT_CONFIG = "/run/config.json"

# --- UID/GID calculés de manière stable ---
def stable_id(name: str, offset: int = 1000, modulo: int = 60000) -> int:
    """Génère un UID/GID stable à partir du nom."""
    digest = hashlib.sha1(name.encode()).hexdigest()
    return offset + (int(digest[:6], 16) % modulo)

# --- helpers système ---
def run(cmd, input_text=None, check=True):
    print(f"[run] {' '.join(cmd)}")
    return subprocess.run(cmd, input=input_text, text=True, check=check)

def group_exists(name):
    return subprocess.run(["getent", "group", name], check=False).returncode == 0

def user_exists(name):
    return subprocess.run(["getent", "passwd", name], check=False).returncode == 0

# --- récupération ou création GID ---
def get_gid(name):
    try:
        gid = grp.getgrnam(name).gr_gid
        print(f"[info] groupe '{name}' existe déjà avec gid={gid}.")
        return gid
    except KeyError:
        # groupe n'existe pas, crée un GID stable
        gid = stable_id(name)
        print(f"[info] groupe '{name}' absent, attribution gid stable={gid}.")
        return gid

# --- récupération ou création UID ---
def get_uid(name):
    try:
        uid = pwd.getpwnam(name).pw_uid
        print(f"[info] utilisateur '{name}' existe déjà avec uid={uid}.")
        return uid
    except KeyError:
        # utilisateur absent, crée un UID stable
        uid = stable_id(name)
        print(f"[info] utilisateur '{name}' absent, attribution uid stable={uid}.")
        return uid

# --- création de groupe ---
def ensure_group(name):
    if group_exists(name):
        return get_gid(name)
    gid = stable_id(name)
    run(["groupadd", "-g", str(gid), name])
    print(f"[ok] groupe '{name}' créé (gid={gid}).")
    return gid

# --- création / mise à jour d'utilisateur ---
def create_user(username, password=None, groups=None, shell="/bin/bash"):
    groups = groups or []

    # Récupère UID (existant ou stable)
    uid = get_uid(username)

    # Groupe primaire = premier groupe dans groups s'il existe, sinon groupe portant même nom que l'utilisateur
    primary_group = groups[0] if groups else username

    # Récupère ou génère GID primaire
    gid = get_gid(primary_group)

    # Assure la création du groupe primaire s'il n'existe pas
    if not group_exists(primary_group):
        run(["groupadd", "-g", str(gid), primary_group])
        print(f"[ok] groupe primaire '{primary_group}' créé (gid={gid}).")

    # Assure la création des groupes secondaires s'ils n'existent pas
    for g in groups[1:] if len(groups) > 1 else []:
        if not group_exists(g):
            gid_g = get_gid(g)
            run(["groupadd", "-g", str(gid_g), g])
            print(f"[ok] groupe secondaire '{g}' créé (gid={gid_g}).")

    if user_exists(username):
        print(f"[info] utilisateur '{username}' existe déjà — mise à jour des groupes.")
        if groups:
            run(["usermod", "-a", "-G", ",".join(groups), username])
            print(f"[ok] groupes supplémentaires appliqués à '{username}': {groups}")
        if password:
            run(["chpasswd"], input_text := f"{username}:{password}\n")
            print(f"[ok] mot de passe mis à jour pour '{username}'.")
        return

    # Création utilisateur en passant le nom du groupe primaire (pas le GID)
    cmd = [
        "useradd",
        "-m",
        "-u", str(uid),
        "-g", str(gid),
        "-s", shell,
    ]

    if not password:
        cmd += ["-p", ""]

    if groups:
        cmd += ["-G", ",".join(groups)]
    cmd.append(username)

    run(cmd)
    print(f"[ok] utilisateur '{username}' créé (uid={uid}, groupe primaire={primary_group}).")

    if password:
        run(["chpasswd"], input_text := f"{username}:{password}\n")
        print(f"[ok] mot de passe défini pour '{username}'.")


# --- chargement config ---
def load_config(path):
    p = Path(path)
    if not p.exists():
        raise SystemExit(f"Config introuvable: {path}")
    return json.loads(p.read_text(encoding="utf-8"))

# --- main ---
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

    # création des groupes globaux
    all_groups = ["users","sudo","docker"]
    for g in sorted(all_groups):
        ensure_group(g)

    # création / mise à jour des utilisateurs
    for u in users:
        name = u.get("name")
        password = u.get("password")  # optionnel
        groups = ["users"]
        if u.get("admin", True):
            groups.append("sudo")
            groups.append("docker")
        shell = u.get("shell", "/bin/bash")

        if not name:
            print(f"[skip] entrée utilisateur incomplète: {u}")
            continue

        try:
            create_user(name, password=password, groups=groups, shell=shell)
        except subprocess.CalledProcessError as e:
            print(f"[error] échec pour {name}: {e}")

if __name__ == "__main__":
    main()
