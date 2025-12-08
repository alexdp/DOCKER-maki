#!/bin/bash

mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "ipv6": false,
  "ip6tables": false,
  "bridge": "none",
  "data-root": "$DOCKER_DATA_ROOT_DIR"
}


mkdir -p /var/local/docker

# Récupère l'image de nginx
echo "Téléchargement de l'image Docker nginx..."
skopeo copy \
  docker://docker.io/library/nginx:1.29.0-alpine-perl \
  docker-archive:/var/local/docker/nginx-latest.tar:nginx:latest
echo "Image Docker nginx téléchargée et enregistrée dans /var/local/docker/nginx-latest.tar"

# Récupère l'image Docker samba dperson 
echo "Téléchargement de l'image Docker Samba..."
skopeo copy \
  docker://docker.io/dperson/samba:latest \
  docker-archive:/var/local/docker/samba-latest.tar:samba:latest
echo "Image Docker Samba téléchargée et enregistrée dans /var/local/docker/samba-latest.tar"

# Récupère l'image de File Browser
echo "Téléchargement de l'image Docker File Browser..."
skopeo copy \
  docker://docker.io/gtstef/filebrowser:0.7.13-beta \
  docker-archive:/var/local/docker/filebrowser-latest.tar:filebrowser:latest
echo "Image Docker File Browser téléchargée et enregistrée dans /var/local/docker/filebrowser-latest.tar"

# Récupère l'image de Jellyfin
echo "Téléchargement de l'image Docker Jellyfin..."
skopeo copy \
  docker://docker.io/linuxserver/jellyfin:10.10.7 \
  docker-archive:/var/local/docker/jellyfin-latest.tar:jellyfin:latest
echo "Image Docker Jellyfin téléchargée et enregistrée dans /var/local/docker/jellyfin-latest.tar"


