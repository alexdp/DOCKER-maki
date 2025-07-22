#!/bin/bash

apt update && add-apt-repository -y universe && apt update && apt install -y docker.io docker-compose ca-certificates gpg skopeo || true

mkdir -p /var/local/docker

# Récupère l'image de nginx
echo "Téléchargement de l'image Docker nginx..."
skopeo copy \
  docker://docker.io/library/nginx:1.29.0-alpine-perl \
  docker-archive:/var/local/docker/nginx-latest.tar:nginx:latest
echo "Image Docker nginx téléchargée et enregistrée dans /var/local/docker/nginx-latest.tar"

# Recupère l'image de Portainer
echo "Téléchargement de l'image Docker Portainer..."
skopeo copy \
  docker://docker.io/portainer/portainer-ce:2.31.3-alpine \
  docker-archive:/var/local/docker/portainer-latest.tar:portainer:latest
echo "Image Docker Portainer téléchargée et enregistrée dans /var/local/docker/portainer-latest.tar"


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

# Récupère l'image de PiGallery2
echo "Téléchargement de l'image Docker PiGallery2..."
skopeo copy \
  docker://docker.io/bpatrik/pigallery2:edge-alpine \
  docker-archive:/var/local/docker/pigallery2-latest.tar:pigallery2:latest
echo "Image Docker PiGallery2 téléchargée et enregistrée dans /var/local/docker/pigallery2-latest.tar"

# Récupère l'image de rclone
echo "Téléchargement de l'image Docker rclone..."
skopeo copy \
  docker://docker.io/rclone/rclone:1.70.3 \
  docker-archive:/var/local/docker/rclone-latest.tar:rclone:latest
echo "Image Docker rclone téléchargée et enregistrée dans /var/local/docker/rclone-latest.tar"


# Récupère les images Docker pour Immich
echo "Téléchargement des images Docker Immich..."
skopeo copy \
  docker://ghcr.io/imagegenius/immich:amd64-noml-v1.135.3-ig316 \
  docker-archive:/var/local/docker/immich-latest.tar:immich:latest
skopeo copy \
  docker://docker.io/valkey/valkey:8-bookworm \
  docker-archive:/var/local/docker/immich-valkey-latest.tar:immich-valkey:latest
skopeo copy \
  docker://ghcr.io/immich-app/postgres:14-vectorchord0.3.0-pgvectors0.2.0 \
  docker-archive:/var/local/docker/immich-postgres-latest.tar:immich-postgres:latest
echo "Images Docker Immich téléchargées et enregistrées dans /var/local/docker/immich*-latest.tar"
