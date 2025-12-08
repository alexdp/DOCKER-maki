#!/bin/bash
set -euo pipefail

python3 /usr/local/bin/load-users-config-linux.py
python3 /usr/local/bin/load-users-config-ldap.py
python3 /usr/local/bin/load-users-config-samba.py

echo "[load-users-config] Création des comptes utilisateurs terminées."
exit 0
