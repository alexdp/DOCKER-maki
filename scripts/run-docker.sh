#!/bin/bash


# Script pour démarrer les services Docker avec les répertoires de données configurés

set -e

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


# Démarrage de Nginx avec Docker (port 80) pour exposer la page web d'accueil
docker load -i /var/local/docker/nginx-latest.tar || true
docker rm --force --volumes nginx || true
docker run -d --name nginx \
  --network host \
  -v /var/www/html:/usr/share/nginx/html:ro \
  nginx:latest || true


# Démarrage de Portainer avec Docker (port 9000) pour la gestion des conteneurs
docker load -i /var/local/docker/portainer-latest.tar || true
docker rm --force --volumes portainer || true
docker run -d --name portainer \
  --network host \
  --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer:latest || true


# Démarrage de Samba avec Docker (port 139 et 445) pour le partage de fichiers
docker load -i /var/local/docker/samba-latest.tar || true
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
docker rm --force --volumes samba || true
docker run -d --name samba \
  --network host \
  -v $ROOT_DIR:/mnt \
  -v /var/local/samba/smb.conf:/etc/samba/smb.conf \
  samba:latest \
  -u "admin;password" \
  -n || true


# Démarrage Filebrowser avec Docker (port 8080) pour la gestion des fichiers
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
docker load -i /var/local/docker/filebrowser-latest.tar || true
docker rm --force --volumes filebrowser || true
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
  filebrowser:latest || true


# Démarrage de Jellyfin avec Docker (port 8096) pour streamer des vidéos
docker load -i /var/local/docker/jellyfin-latest.tar || true
docker rm --force --volumes jellyfin || true
docker run -d \
  --name=jellyfin \
  --network host \
  -e PUID=$(id -u smbuser) \
  -e PGID=$(id -g smbuser) \
  -e TZ=Etc/UTC \
  -v jellyfin_config:/config \
  -v jellyfin_cache:/cache \
  -v $VIDEOS_DIR:/media:ro \
  jellyfin:latest || true


# Démarrage de PiGallery2 avec Docker (port 8082) pour la lecture des photos
docker load -i /var/local/docker/pigallery2-latest.tar || true
mkdir -p /var/local/pigallery2 || true
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
docker rm --force --volumes pigallery2 || true
docker run -d \
  --name pigallery2 \
  --network host \
  --user $(id -u smbuser):$(id -g smbuser) \
  -v $PHOTOS_DIR:/app/data/images:ro \
  -v /var/local/pigallery2/config.json:/app/data/config/config.json:ro \
  -v pigallery2_db:/app/data/db \
  pigallery2:latest || true



# Démarrage de Immich avec Docker (port 8088) pour la gestion des photos
docker load -i /var/local/docker/immich-latest.tar || true
docker load -i /var/local/docker/immich-valkey-latest.tar || true
docker load -i /var/local/docker/immich-postgres-latest.tar || true
docker rm --force --volumes immich || true
docker rm --force --volumes immich-valkey || true
docker rm --force immich-postgres || true
docker run -d --name immich-postgres \
  --network host \
  -e POSTGRES_USER=immich \
  -e POSTGRES_PASSWORD=immich \
  -e POSTGRES_DB=immich \
  -v immich_postgres_data:/var/lib/postgresql/data \
  immich-postgres:latest || true
docker run -d --name immich-valkey \
  --network host \
  -e VALKEY_PASSWORD=immich \
  -e VALKEY_DATABASE=immich \
  -e VALKEY_PORT=6379 \
  -v immich_valkey_data:/data \
  immich-valkey:latest || true
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
  -v $PHOTOS_DIR:/photos \
  immich:latest || true

  