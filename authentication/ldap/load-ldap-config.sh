#!/bin/bash
set -e

echo "[ldap-config] Applying configuration LDIFs..."

# Charger les schémas LDAP nécessaires
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/core.ldif || true
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/cosine.ldif || true
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/nis.ldif || true
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/inetorgperson.ldif || true

# Appliquer les fichiers de configuration (bases, ACL) avec SASL EXTERNAL
for f in /etc/ldap/config/*.ldif; do
  echo "→ Loading config $f"
  ldapmodify -Y EXTERNAL -H ldapi:/// -f "$f" || ldapadd -Y EXTERNAL -H ldapi:/// -f "$f" || true
done

# Appliquer les fichiers de données (domaines, OUs, users, groups) avec bind admin
for f in /etc/ldap/model/*.ldif; do
  echo "→ Loading data $f"
  ldapmodify -x -D "cn=admin,dc=domain,dc=lan" -w admin -f "$f" || ldapadd -x -D "cn=admin,dc=domain,dc=lan" -w admin -f "$f" || true
done

echo "[ldap-config] Configuration applied."

