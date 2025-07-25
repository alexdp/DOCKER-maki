#!/bin/bash

apt update && apt install -y curl unzip fuse3 || true

cd /tmp || exit 1

# Fetch and unpack
curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip
unzip rclone-current-linux-amd64.zip
cd rclone-*-linux-amd64

# Copy binary file
cp rclone /usr/bin/
chown root:root /usr/bin/rclone
chmod 755 /usr/bin/rclone

# Delete temporary files
cd ..
rm -rf rclone-*-linux-amd64.zip rclone-*-linux-amd

# Décommente ou ajoute user_allow_other dans /etc/fuse.conf
if ! grep -q "user_allow_other" /etc/fuse.conf; then
    echo "user_allow_other" >> /etc/fuse.conf
fi



