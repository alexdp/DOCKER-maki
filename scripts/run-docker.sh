#!/bin/bash


# Script pour démarrer les services Docker avec les répertoires de données configurés

set -e

# Ajoute le user smbuser/smbuser utlisé pour Samba, File Browser, Immich.
adduser --system --no-create-home --group smbuser > /dev/null


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
docker load -i /var/local/docker/nginx-latest.tar
docker rm --force --volumes nginx > /dev/null
docker run -d --name nginx \
  --network host \
  -v /var/www/html:/usr/share/nginx/html:ro \
  nginx:latest && \
timeout 60 bash -c 'until docker ps | grep -q nginx; do sleep 5; done'



# Démarrage de Portainer avec Docker (port 9000) pour la gestion des conteneurs
docker load -i /var/local/docker/portainer-latest.tar
docker rm --force --volumes portainer > /dev/null
docker run -d --name portainer \
  --network host \
  --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer:latest && \
timeout 60 bash -c 'until docker ps | grep -q portainer; do sleep 5; done'


# Démarrage de Samba avec Docker (port 139 et 445) pour le partage de fichiers
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
docker rm --force --volumes samba > /dev/null
docker run -d --name samba \
  --network host \
  -v $ROOT_DIR:/mnt \
  -v /var/local/samba/smb.conf:/etc/samba/smb.conf \
  samba:latest \
  -n && \
timeout 60 bash -c 'until docker ps | grep -q samba; do sleep 5; done'


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
docker load -i /var/local/docker/filebrowser-latest.tar
docker rm --force --volumes filebrowser > /dev/null
docker run -d \
  --name filebrowser \
  --network host \
  -v filebrowser_data:/database \
  -v /var/local/filebrowser/config.yaml:/home/filebrowser/config.yaml \
  -v $ROOT_DIR:/srv \
  -e PUID=$(id -u smbuser) \
  -e PGID=$(id -g smbuser) \
  -e FB_USER=admin \
  -e FB_PASSWORD=password \
  filebrowser:latest && \
timeout 60 bash -c 'until docker ps | grep -q filebrowser; do sleep 5; done'


# Démarrage de Jellyfin avec Docker (port 8096) pour streamer des vidéos
docker load -i /var/local/docker/jellyfin-latest.tar
docker rm --force --volumes jellyfin > /dev/null
docker run -d \
  --name=jellyfin \
  --network host \
  -e PUID=$(id -u smbuser) \
  -e PGID=$(id -g smbuser) \
  -e TZ=Etc/UTC \
  -v jellyfin_config:/config \
  -v jellyfin_cache:/cache \
  -v $VIDEOS_DIR:/media:ro \
  jellyfin:latest && \
# Attendre que le conteneur soit prêt
timeout 60 bash -c 'until docker ps | grep -q jellyfin; do sleep 5; done'


# Démarrage de PiGallery2 avec Docker (port 8082) pour la lecture des photos
docker load -i /var/local/docker/pigallery2-latest.tar
mkdir -p /var/local/pigallery2 > /dev/null
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
docker rm --force --volumes pigallery2 > /dev/null
docker run -d \
  --name pigallery2 \
  --network host \
  --user $(id -u smbuser):$(id -g smbuser) \
  -v $PHOTOS_DIR:/app/data/images:ro \
  -v /var/local/pigallery2/config.json:/app/data/config/config.json:ro \
  -v pigallery2_db:/app/data/db \
  pigallery2:latest && \
# Attendre que le conteneur soit prêt
timeout 60 bash -c 'until docker ps | grep -q pigallery2; do sleep 5; done'



# Démarrage de Immich avec Docker (port 8088) pour la gestion des photos
docker load -i /var/local/docker/immich-latest.tar
docker load -i /var/local/docker/immich-valkey-latest.tar
docker load -i /var/local/docker/immich-postgres-latest.tar
docker rm --force --volumes immich > /dev/null
docker rm --force --volumes immich-valkey > /dev/null
docker rm --force immich-postgres > /dev/null
docker run -d --name immich-postgres \
  --network host \
  -e POSTGRES_USER=immich \
  -e POSTGRES_PASSWORD=immich \
  -e POSTGRES_DB=immich \
  -v immich_postgres_data:/var/lib/postgresql/data \
  immich-postgres:latest && \
timeout 60 bash -c 'until docker ps | grep -q immich-postgres; do sleep 5; done'
docker run -d --name immich-valkey \
  --network host \
  -e VALKEY_PASSWORD=immich \
  -e VALKEY_DATABASE=immich \
  -e VALKEY_PORT=6379 \
  -v immich_valkey_data:/data \
  immich-valkey:latest && \
timeout 60 bash -c 'until docker ps | grep -q immich-valkey; do sleep 5; done'
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
  immich:latest && \
timeout 60 bash -c 'until docker ps | grep -q immich; do sleep 5; done'

