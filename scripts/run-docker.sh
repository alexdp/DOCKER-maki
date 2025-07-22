#!/bin/bash

set -e

# Préparation de l'environnement Docker
DOCKER_DATA_ROOT_DIR="/tmp/docker"
# Trouver un disque monté en écriture (chercher dans /mnt car c'est là que sont montés les disques de données)
FIRST_MOUNT=$(ls -1 /mnt 2>/dev/null | head -n 1)
if [ -n "$FIRST_MOUNT" ]; then
    FIRST_MOUNT="/mnt/$FIRST_MOUNT"
fi

if [ -z "$FIRST_MOUNT" ] || [ ! -d "$FIRST_MOUNT" ]; then
    echo "Aucun disque monté en écriture trouvé dans /mnt. Docker utilisera /tmp/docker"
    # Vérifier si on peut écrire dans /tmp
    if ! touch /tmp/test_write 2>/dev/null; then
        echo "Impossible d'écrire dans /tmp, utilisation de /var/lib/docker"
        DOCKER_DATA_ROOT_DIR="/var/lib/docker"
    else
        rm -f /tmp/test_write
    fi
else
    echo "Disque monté en écriture trouvé : $FIRST_MOUNT"
    # Vérifier si on peut écrire sur ce disque
    if touch "$FIRST_MOUNT/.test_write" 2>/dev/null; then
        DOCKER_DATA_ROOT_DIR="$FIRST_MOUNT/.docker"
        rm -f "$FIRST_MOUNT/.test_write"
    else
        echo "Le disque $FIRST_MOUNT n'est pas accessible en écriture, utilisation de /tmp/docker"
    fi
fi
mkdir -p "$DOCKER_DATA_ROOT_DIR"
chmod 700 "$DOCKER_DATA_ROOT_DIR"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "ipv6": false,
  "ip6tables": false,
  "bridge": "none",
  "data-root": "$DOCKER_DATA_ROOT_DIR"
}
EOF
systemctl restart docker
echo "Docker configuré avec le répertoire de données : $DOCKER_DATA_ROOT_DIR"


# Démarrage de Nginx avec Docker
docker load -i /var/local/docker/nginx-latest.tar
docker rm --force --volumes nginx
docker run -d --name nginx \
  --network host \
  -v /var/www/html:/usr/share/nginx/html:ro \
  nginx:latest


# Démarrage de Portainer avec Docker
docker load -i /var/local/docker/portainer-latest.tar
docker rm --force --volumes portainer
docker run -d --name portainer \
  --network host \
  --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer:latest


# Démarrage de Samba avec Docker
adduser --system --no-create-home --group smbuser
docker load -i /var/local/docker/samba-latest.tar
mkdir -p /var/local/samba 
cat > /var/local/samba/smb.conf << EOF
[global]
   map to guest = Bad User
   server role = standalone server
   security = user
   workgroup = WORKGROUP
   
[public]
   comment = Public Share - Linux Users Only
   path = /mnt
   browsable = yes
   writable = yes
   guest ok = no
   read only = no
   create mask = 0666
   create directory = 0777
EOF
docker rm --force --volumes samba
docker run -d --name samba \
  --network host \
  -v $FIRST_MOUNT:/mnt \
  -v /var/local/samba/smb.conf:/etc/samba/smb.conf \
  samba:latest \
  -u "admin;password" \
  -n


# Démarrage Filebrowser avec Docker
mkdir -p /var/local/filebrowser
cat > /var/local/filebrowser/config.yaml << EOF
server:
  port: 8080
  baseURL:  "/"
  logging:
    - levels: "info|warning|error"
  sources:
    - path: "/srv"
auth:
  methods:
    noauth: true
userDefaults:
  preview:
    image: true
    popup: true
    video: true
    office: false
    highQuality: false
  darkMode: true
  disableSettings: false
  singleClick: false
  permissions:
    admin: false
    modify: true
    share: false
    api: false
EOF
docker load -i /var/local/docker/filebrowser-latest.tar
docker rm --force --volumes filebrowser
docker run -d \
  --name filebrowser \
  --network host \
  -v filebrowser_data:/database \
  -v /var/local/filebrowser/config.yaml:/home/filebrowser/config.yaml \
  -v $FIRST_MOUNT:/srv \
  -e PUID=$(id -u smbuser) \
  -e PGID=$(id -g smbuser) \
  -e FB_USER=admin \
  -e FB_PASSWORD=password \
  filebrowser:latest

echo "✓ File Browser démarré avec Docker sur le port 8080"

# Démarrage de Jellyfin avec Docker
docker load -i /var/local/docker/jellyfin-latest.tar
docker rm --force --volumes jellyfin
docker run -d \
  --name=jellyfin \
  --network host \
  -e PUID=$(id -u smbuser) \
  -e PGID=$(id -g smbuser) \
  -e TZ=Etc/UTC \
  -v jellyfin_config:/config \
  -v jellyfin_cache:/cache \
  -v /mnt:/media:ro \
  jellyfin:latest


# Démarrage de PiGallery2 avec Docker
docker load -i /var/local/docker/pigallery2-latest.tar
mkdir -p /var/local/pigallery2
cat > /var/local/pigallery2/config.json << EOF
{
  "Server": {
    "port": 8082
  },
  "Users": {
    "authenticationRequired": false,
    "unAuthenticatedUserRole": "Admin"
  }
}
EOF
docker rm --force --volumes pigallery2
docker run -d \
  --name pigallery2 \
  --network host \
  -v /mnt:/app/data/images:ro \
  -v /var/local/pigallery2/config.json:/app/data/config/config.json:ro \
  -v pigallery2_db:/app/data/db \
  pigallery2:latest



# Démarrage de Immich avec Docker
docker load -i /var/local/docker/immich-latest.tar
docker load -i /var/local/docker/immich-valkey-latest.tar
docker load -i /var/local/docker/immich-postgres-latest.tar
docker rm --force --volumes immich
docker rm --force --volumes immich-valkey
docker rm --force immich-postgres
docker run -d --name immich-postgres \
  --network host \
  -e POSTGRES_USER=immich \
  -e POSTGRES_PASSWORD=immich \
  -e POSTGRES_DB=immich \
  -v immich_postgres_data:/var/lib/postgresql/data \
  immich-postgres:latest
docker run -d --name immich-valkey \
  --network host \
  -e VALKEY_PASSWORD=immich \
  -e VALKEY_DATABASE=immich \
  -e VALKEY_PORT=6379 \
  -v immich_valkey_data:/data \
  immich-valkey:latest
docker run -d --name immich \
  --network host \
  -e PUID=$(id -u smbuser) \
  -e PGID=$(id -g smbuser) \
  -e DB_HOSTNAME=localhost \
  -e DB_USERNAME=immich \
  -e DB_PASSWORD=immich \
  -e DB_DATABASE_NAME=immich \
  -e REDIS_HOSTNAME=localhost \
  -e SERVER_HOST=0.0.0.0 \
  -e SERVER_PORT=8088 \
  -v $FIRST_MOUNT:/photos \
  immich:latest

  