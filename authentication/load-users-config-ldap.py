#!/usr/bin/env python3
import json
import hashlib
from ldap3 import Server, Connection, ALL, MODIFY_REPLACE
from pathlib import Path
import grp
import pwd

# --- CONFIGURATION LDAP ---
LDAP_URI = "ldap://localhost"
BIND_DN = "cn=admin,dc=domain,dc=lan"
BIND_PW = "admin"
BASE_DN = "dc=domain,dc=lan"
USERS_OU = "ou=Users," + BASE_DN
GROUPS_OU = "ou=Groups," + BASE_DN

# --- UID/GID calculés de manière stable ---
def stable_id(name: str, offset: int = 1000, modulo: int = 60000) -> int:
    """
    Génère un UID ou GID stable à partir du nom, dans une plage déterminée.
    """
    digest = hashlib.sha1(name.encode()).hexdigest()
    return offset + (int(digest[:6], 16) % modulo)

# --- Récupération ou génération GID local ---
def get_gid(name):
    try:
        gid = grp.getgrnam(name).gr_gid
        print(f"[info] Groupe système '{name}' existe avec gid={gid}")
        return gid
    except KeyError:
        gid = stable_id(name)
        print(f"[info] Groupe système '{name}' absent, gid stable attribué={gid}")
        return gid

# --- Récupération ou génération UID local ---
def get_uid(name):
    try:
        uid = pwd.getpwnam(name).pw_uid
        print(f"[info] Utilisateur système '{name}' existe avec uid={uid}")
        return uid
    except KeyError:
        uid = stable_id(name)
        print(f"[info] Utilisateur système '{name}' absent, uid stable attribué={uid}")
        return uid

# --- Connexion LDAP ---
def connect():
    server = Server(LDAP_URI, get_info=ALL)
    conn = Connection(server, BIND_DN, BIND_PW, auto_bind=True)
    return conn

# --- Création des OU si manquantes ---
def ensure_ou(conn, ou_name):
    dn = f"ou={ou_name},{BASE_DN}"
    if not conn.search(dn, "(objectClass=organizationalUnit)"):
        print(f"[+] Création de {dn}")
        conn.add(dn, ["top", "organizationalUnit"], {"ou": ou_name})

# --- Création d’un groupe dans LDAP ---
def create_group(conn, name):
    gid = get_gid(name)
    dn = f"cn={name},{GROUPS_OU}"
    if not conn.search(dn, "(objectClass=posixGroup)"):
        print(f"[+] Création du groupe LDAP {name} (gid={gid})")
        conn.add(dn, ["top", "posixGroup"], {"cn": name, "gidNumber": str(gid)})
    return dn, gid

# --- Création d’un utilisateur dans LDAP ---
def create_user(conn, name, password, groups):
    uid = get_uid(name)
    primary_gid = get_gid(groups[0]) if groups else uid
    dn = f"uid={name},{USERS_OU}"

    if not conn.search(dn, "(objectClass=posixAccount)"):
        print(f"[+] Création utilisateur LDAP {name} (uid={uid})")
        attrs = {
            "objectClass": ["inetOrgPerson", "posixAccount", "top"],
            "cn": name,
            "sn": name,
            "uid": name,
            "uidNumber": str(uid),
            "gidNumber": str(primary_gid),
            "homeDirectory": f"/home/{name}",
            "loginShell": "/bin/bash",
            "userPassword": password,
        }
        conn.add(dn, attributes=attrs)

    # Ajoute l'utilisateur aux groupes (modifie memberUid)
    for g in groups:
        g_dn = f"cn={g},{GROUPS_OU}"
        if conn.search(g_dn, "(objectClass=posixGroup)", attributes=["memberUid"]):
            current_members = conn.entries[0].memberUid.values if "memberUid" in conn.entries[0] else []
            new_members = list(set(current_members) | {name})
            conn.modify(g_dn, {"memberUid": [(MODIFY_REPLACE, new_members)]})
        else:
            gid = get_gid(g)
            conn.add(g_dn, ["top", "posixGroup"], {"cn": g, "gidNumber": str(gid), "memberUid": [name]})
            print(f"[+] Création groupe LDAP {g} avec membre {name}")

# --- Programme principal ---
def main():
    config_file = Path("/run/config.json")
    if not config_file.exists():
        config_file = Path("config.json")

    with open(config_file) as f:
        cfg = json.load(f)

    conn = connect()
    ensure_ou(conn, "Users")
    ensure_ou(conn, "Groups")

    # Crée les groupes dans LDAP
    all_groups = ["users","sudo","docker"]
    for g in sorted(all_groups):
        create_group(conn, g)

    # Crée les utilisateurs dans LDAP
    for u in cfg["users"]:
        groups = ["users"]
        if u.get("admin", True):
            groups.append("sudo")
            groups.append("docker")
        create_user(conn, u["name"], u.get("password", "password"), groups)

    conn.unbind()
    print("Importation terminée avec succès.")

if __name__ == "__main__":
    main()