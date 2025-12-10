# Dockerfile pour construire l'image ISO Ubuntu live custom
FROM ubuntu:24.04

# Variables d'environnement
ENV UBUNTU_VERSION="noble"
ENV ARCH="amd64"
ENV DEBIAN_FRONTEND=noninteractive
ENV CHROOT_DIR="/workspace/build/chroot"
ENV IMAGE_DIR="/workspace/build/image"
ENV ISO_NAME="live-nas.iso"

# Installation des paquets nécessaires pour la construction de l'ISO
RUN apt-get update && apt-get install -y \
    debootstrap \
    grub-pc-bin \
    grub-efi-amd64-bin \
    xorriso \
    mtools \
    squashfs-tools \
    genisoimage \
    isolinux \
    syslinux-utils \
    mount \
    curl \
    wget


###########################################
#                                         #
# Préparation de l'arborescence de l'hote #
#                                         #
###########################################
# Créer le chroot avec debootstrap
RUN echo "Création du chroot avec debootstrap..."
RUN mkdir -p $CHROOT_DIR
# Utiliser un miroir alternatif et --no-check-gpg pour debootstrap
ENV DEBOOTSTRAP_MIRROR="http://fr.archive.ubuntu.com/ubuntu/"
RUN debootstrap --variant=minbase --no-check-gpg --arch=$ARCH $UBUNTU_VERSION $CHROOT_DIR $DEBOOTSTRAP_MIRROR


########################################
#                                      #
# installation des paquets dans l'ISO  #
#                                      #
########################################
RUN chroot $CHROOT_DIR apt install -y software-properties-common
RUN chroot $CHROOT_DIR add-apt-repository -y universe && chroot $CHROOT_DIR apt update && chroot $CHROOT_DIR apt install -y \
    # Installation des paquets utilitaires de base
    sudo \
    curl \
    gnupg \
    wget \
    unzip \
    nano \
    vim \
    htop \
    net-tools \
    iputils-ping \
    socat \
    cron \
    rsync \
    acl \
    # Installation des paquets essentiels pour un live system
    initramfs-tools \
    casper \
    linux-image-generic \
    # Installation des paquets pour la lecture du fichier de configuration au format JSON
    jq \
    # Installation du paquet pour la conversion des fichiers texte Windows (CRLF) en fichiers texte Unix (LF)
    # pour le fichier de configuration monté depuis la clé USB en FAT32
    dos2unix \
    # Installation des paquets pour le partage de fichiers avec Samba
    samba \
    smbclient \
    ldap-utils \
    wsdd \
    # Installation des paquets pour la gestion réseau
    wpasupplicant \
    avahi-daemon \
    avahi-utils \
    # Installation des paquets pour le service annuaire LDAP
    slapd \
    ldap-utils \
    # Installation des dépendances Python pour charger les comptes LDAP
    python3-pip \
    python3-ldap3 \
    # Installation des paquets Docker et ses dépendances
    docker.io \
    docker-compose \
    ca-certificates \
    gpg \
    skopeo \
    # Installation du reverse proxy nginx
    nginx \
    # Installation terminal web SSH
    shellinabox \
    # Package requis par Rclone pour le support des systèmes de fichiers cloud
    fuse3 \
    # Installation des outils pour le monitoring des changements de fichiers (utilisé par rclone automount)
    inotify-tools


##################################################################################
#                                                                                #
# Préparation de l'environnement de boot de l'ISO:                               #
# * Lecture configuration depuis clé USB (fichier config.json)                   #     
# * Chargement des variables d'environnement                                     #
# * Création des utilisateurs et groupes                                         #
# * Configuration réseau                                                         #
# * Détection et montage des disques durs                                        #
#                                                                                #
##################################################################################


# Charge les variables de configuration depuis la clé USB au démarrage (fichier config.json)
COPY boot/environment/load-usb-config.service $CHROOT_DIR/usr/lib/systemd/system/
COPY boot/environment/load-usb-config.sh $CHROOT_DIR/usr/local/bin/
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/load-usb-config.service
RUN chmod +x $CHROOT_DIR/usr/local/bin/load-usb-config.sh
RUN chroot $CHROOT_DIR systemctl enable load-usb-config.service

# Prépare la stack réseau avec DHCP et envoi du hostname au démarrage
COPY boot/network/load-network-config.service $CHROOT_DIR/usr/lib/systemd/system/
COPY boot/network/load-network-config.sh $CHROOT_DIR/usr/local/bin/
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/load-network-config.service
RUN chmod +x $CHROOT_DIR/usr/local/bin/load-network-config.sh
RUN chroot $CHROOT_DIR systemctl enable load-network-config.service
RUN chroot $CHROOT_DIR systemctl disable systemd-networkd.service
RUN chroot $CHROOT_DIR systemctl disable systemd-resolved.service
RUN chroot $CHROOT_DIR systemctl disable avahi-daemon.service
RUN chroot $CHROOT_DIR systemctl disable getty@tty1.service

# Configure l'accès SSH au démarrage
RUN chroot $CHROOT_DIR apt install -y openssh-server
COPY authentication/ssh/sshd_config $CHROOT_DIR/etc/ssh/sshd_config

# Configure les paramètres Bash par défaut (couleurs et alias)
COPY authentication/bash/bash.bashrc $CHROOT_DIR/etc/bash.bashrc
COPY authentication/bash/bash.bashrc $CHROOT_DIR/etc/skel/.bashrc    

# Configure le clavier en français par défaut
RUN chroot $CHROOT_DIR apt install -y console-setup keyboard-configuration
RUN chroot $CHROOT_DIR bash -c "echo 'XKBLAYOUT=\"fr\"' >> /etc/default/keyboard"
RUN chroot $CHROOT_DIR bash -c "echo 'BACKSPACE=\"guess\"' >> /etc/default/keyboard"
RUN chroot $CHROOT_DIR setupcon

# Prépare l'ajout des utilisateurs définis dans le fichier config.json au boot
COPY authentication/load-users-config.service $CHROOT_DIR/usr/lib/systemd/system/
COPY authentication/load-users-config.sh $CHROOT_DIR/usr/local/bin/
COPY authentication/load-users-config-linux.py $CHROOT_DIR/usr/local/bin/
COPY authentication/load-users-config-ldap.py $CHROOT_DIR/usr/local/bin/
COPY authentication/load-users-config-samba.py $CHROOT_DIR/usr/local/bin/
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/load-users-config.service
RUN chmod +x $CHROOT_DIR/usr/local/bin/load-users-config.sh
RUN chroot $CHROOT_DIR systemctl enable load-users-config.service

# Configure le service LDAP (non nécessaire mais peut être utile par des applications)
COPY authentication/ldap/config $CHROOT_DIR/etc/ldap/config
COPY authentication/ldap/model $CHROOT_DIR/etc/ldap/model
COPY authentication/ldap/load-ldap-config.service $CHROOT_DIR/usr/lib/systemd/system/
COPY authentication/ldap/load-ldap-config.sh $CHROOT_DIR/usr/local/bin/
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/load-ldap-config.service
RUN chmod +x $CHROOT_DIR/usr/local/bin/load-ldap-config.sh
RUN chroot $CHROOT_DIR systemctl enable load-ldap-config.service
# (Optionnel) pas pour l'authentification - seulement si vous voulez faire ldapsearch depuis la ligne de commande
COPY authentication/ldap/ldap.conf $CHROOT_DIR/etc/ldap/ldap.conf

# Configure le montage automatique des volumes au démarrage
COPY boot/storage/mount-all-disks.service $CHROOT_DIR/etc/systemd/system/
COPY boot/storage/mount-all-disks.sh $CHROOT_DIR/usr/local/bin/
RUN chmod -x $CHROOT_DIR/etc/systemd/system/mount-all-disks.service
RUN chmod +x $CHROOT_DIR/usr/local/bin/mount-all-disks.sh
RUN chroot $CHROOT_DIR systemctl enable mount-all-disks.service





#######################################################
#                                                     #
# Installation et/ou configuration des applications : #
# * Docker pour lancer les conteneurs                 #
# * FileBrowser pour la gestion de fichiers web       #
# * Jellyfin pour le streaming vidéo                  #
# * PiGallery2 pour la visualisation de photos        #
# * Samba pour le partage de fichiers                 #
# * Nginx pour le reverse proxy et portail web        #
# * Shellinabox pour le terminal web SSH              #
#                                                     #
#######################################################


# Configure Docker (l'installation est déjà faite plus haut)
COPY apps/docker/load-docker-config.service $CHROOT_DIR/etc/systemd/system/
COPY apps/docker/load-docker-config.sh $CHROOT_DIR/usr/local/bin/
RUN chmod -x $CHROOT_DIR/etc/systemd/system/load-docker-config.service
RUN chmod +x $CHROOT_DIR/usr/local/bin/load-docker-config.sh
RUN chroot $CHROOT_DIR systemctl enable load-docker-config.service


# Installe et configure le gestionnaire de fichier web FileBrowser
COPY apps/filebrowser/linux-amd64-filebrowser-v2.45.1.tar.gz $CHROOT_DIR/tmp/linux-amd64-filebrowser.tar.gz
RUN chroot $CHROOT_DIR bash -c "cd /tmp && tar -xvf linux-amd64-filebrowser.tar.gz && mv filebrowser /usr/local/bin/filebrowser && rm linux-amd64-filebrowser.tar.gz"
COPY apps/filebrowser/launch-filebrowser.sh $CHROOT_DIR/usr/local/bin/launch-filebrowser.sh
RUN chmod a+x $CHROOT_DIR/usr/local/bin/launch-filebrowser.sh
RUN chmod a+x $CHROOT_DIR/usr/local/bin/filebrowser
RUN mkdir -p $CHROOT_DIR/etc/filebrowser
COPY apps/filebrowser/filebrowser.service $CHROOT_DIR/usr/lib/systemd/system/filebrowser.service
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/filebrowser.service
RUN chroot $CHROOT_DIR systemctl enable filebrowser.service


# Installe et configure le serveur de streaming vidéo Jellyfin
RUN chroot $CHROOT_DIR /bin/bash -c "curl https://repo.jellyfin.org/install-debuntu.sh | sudo bash"
COPY apps/jellyfin/load-jellyfin-config.service $CHROOT_DIR/usr/lib/systemd/system/
COPY apps/jellyfin/load-jellyfin-config.sh $CHROOT_DIR/usr/local/bin/load-jellyfin-config.sh
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/load-jellyfin-config.service
RUN chmod +x $CHROOT_DIR/usr/local/bin/load-jellyfin-config.sh
RUN chroot $CHROOT_DIR systemctl enable load-jellyfin-config.service


# Installe et configure l'application web de visualisation de photos PiGallery2 (nécessite nodejs)
RUN chroot $CHROOT_DIR /bin/bash -c "curl -fsSL https://deb.nodesource.com/setup_22.x | bash -"
RUN chroot $CHROOT_DIR apt install -y nodejs
COPY apps/pigallery2/pigallery2-release.zip $CHROOT_DIR/opt/pigallery2.zip
RUN chroot $CHROOT_DIR bash -c "cd /opt && unzip pigallery2.zip -d pigallery2"
RUN chroot $CHROOT_DIR bash -c "cd /opt/pigallery2 && npm install --production"
RUN chroot $CHROOT_DIR bash -c "rm /opt/pigallery2.zip"
COPY apps/pigallery2/config.json $CHROOT_DIR/opt/pigallery2/config.json
COPY apps/pigallery2/launch-pigallery2.sh $CHROOT_DIR/usr/local/bin/launch-pigallery2.sh
RUN chmod +x $CHROOT_DIR/usr/local/bin/launch-pigallery2.sh
COPY apps/pigallery2/pigallery2.service $CHROOT_DIR/usr/lib/systemd/system/pigallery2.service
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/pigallery2.service
RUN chroot $CHROOT_DIR systemctl enable pigallery2.service


# Configure le serveur de partage de fichiers Samba (l'installation est déjà faite plus haut)
COPY apps/samba/smb.conf $CHROOT_DIR/etc/samba/smb.conf
COPY apps/samba/load-samba-config.service $CHROOT_DIR/usr/lib/systemd/system/
COPY apps/samba/load-samba-config.sh $CHROOT_DIR/usr/local/bin/load-samba-config.sh
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/load-samba-config.service
RUN chmod +x $CHROOT_DIR/usr/local/bin/load-samba-config.sh
RUN chroot $CHROOT_DIR systemctl enable load-samba-config.service



# Configure le reverse proxy et portail web des services Nginx (l'installation est déjà faite plus haut)
COPY apps/nginx/portal.conf $CHROOT_DIR/etc/nginx/sites-available/portal.conf 
RUN chroot $CHROOT_DIR ln -s /etc/nginx/sites-available/portal.conf /etc/nginx/sites-enabled/portal.conf
RUN chroot $CHROOT_DIR rm /etc/nginx/sites-enabled/default
COPY apps/nginx/www $CHROOT_DIR/var/www/html
COPY apps/nginx/load-portal-cards.service $CHROOT_DIR/usr/lib/systemd/system/
COPY apps/nginx/load-portal-cards.sh $CHROOT_DIR/usr/local/bin/load-portal-cards.sh
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/load-portal-cards.service
RUN chmod +x $CHROOT_DIR/usr/local/bin/load-portal-cards.sh
RUN chroot $CHROOT_DIR systemctl enable load-portal-cards.service


# Configure le terminal web SSH Shellinabox (l'installation est déjà faite plus haut)
RUN sed -i "s|^SHELLINABOX_ARGS=.*$|SHELLINABOX_ARGS=\"--no-beep --disable-ssl --localhost-only --css=/etc/shellinabox/options-enabled/'00_White On Black.css'\"|" $CHROOT_DIR/etc/default/shellinabox


# Installe et configure Kopia pour les sauvegardes
COPY apps/kopia/kopia_0.22.2_linux_amd64.deb $CHROOT_DIR/tmp/kopia_linux_amd64.deb
RUN chroot $CHROOT_DIR bash -c "cd /tmp && apt install -y ./kopia_linux_amd64.deb"
RUN rm $CHROOT_DIR/tmp/kopia_linux_amd64.deb
COPY apps/kopia/load-kopia-admin-user.py $CHROOT_DIR/usr/local/bin/
COPY apps/kopia/kopia.service $CHROOT_DIR/usr/lib/systemd/system/kopia.service
COPY apps/kopia/launch-kopia.sh $CHROOT_DIR/usr/local/bin/launch-kopia.sh
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/kopia.service
RUN chmod +x $CHROOT_DIR/usr/local/bin/launch-kopia.sh
RUN chroot $CHROOT_DIR systemctl enable kopia.service

# Installe et configure RClone pour les synchronisations cloud
# Modifie rclone avec un wrapper pour remplacer les URLs localhost par le nom DNS de la machine
# Déploie un script de montage automatique des remotes définis dans le fichier de configuration rclone
COPY apps/rclone/rclone-v1.72.0-linux-amd64.deb $CHROOT_DIR/tmp/rclone-linux-amd64.deb
RUN chroot $CHROOT_DIR bash -c "cd /tmp && apt install -y ./rclone-linux-amd64.deb"
RUN rm $CHROOT_DIR/tmp/rclone-linux-amd64.deb
RUN mv $CHROOT_DIR/usr/bin/rclone $CHROOT_DIR/usr/bin/rclone.real
COPY apps/rclone/rclone_wrapper $CHROOT_DIR/usr/bin/rclone
RUN chmod +x $CHROOT_DIR/usr/bin/rclone
COPY apps/rclone/load-rclone-config.service $CHROOT_DIR/usr/lib/systemd/system/
COPY apps/rclone/load-rclone-config.sh $CHROOT_DIR/usr/local/bin/load-rclone-config.sh
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/load-rclone-config.service
RUN chmod +x $CHROOT_DIR/usr/local/bin/load-rclone-config.sh
RUN chroot $CHROOT_DIR systemctl enable load-rclone-config.service
COPY apps/rclone/rclone-automount.service $CHROOT_DIR/usr/lib/systemd/system/
COPY apps/rclone/rclone-automount.sh $CHROOT_DIR/usr/local/bin/rclone-automount.sh
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/rclone-automount.service
RUN chmod +x $CHROOT_DIR/usr/local/bin/rclone-automount.sh
RUN chroot $CHROOT_DIR systemctl enable rclone-automount.service
COPY apps/rclone/launch-rclone-socat.service $CHROOT_DIR/usr/lib/systemd/system/
RUN chmod -x $CHROOT_DIR/usr/lib/systemd/system/launch-rclone-socat.service
RUN chroot $CHROOT_DIR systemctl enable launch-rclone-socat.service
RUN sed -i 's|^#user_allow_other$|user_allow_other|' $CHROOT_DIR/etc/fuse.conf



#########################################
#                                       #
# Création de l'image ISO personnalisée #
#                                       #
#########################################
# Nettoyer le chroot avant de créer l'ISO
RUN chroot $CHROOT_DIR apt update && \
    chroot $CHROOT_DIR apt-get autoremove -y --purge && \
    chroot $CHROOT_DIR apt-get clean && \
    rm -rf $CHROOT_DIR/var/lib/apt/lists/* \
           $CHROOT_DIR/tmp/* \
           $CHROOT_DIR/var/tmp/* \
           $CHROOT_DIR/usr/share/doc/* \
           $CHROOT_DIR/usr/share/man/* \
           $CHROOT_DIR/usr/share/info/* \
           $CHROOT_DIR/var/cache/*
# Générer l'initramfs
RUN chroot $CHROOT_DIR update-initramfs -u
# Créer l'image squashfs contenant les fichiers du chroot
RUN mkdir -p $IMAGE_DIR/casper
RUN mksquashfs $CHROOT_DIR $IMAGE_DIR/casper/filesystem.squashfs -e boot -comp xz -Xbcj x86 -b 1M
# Copier les fichiers kernel et initrd (prendre le plus récent)
RUN KERNEL_FILE=$(ls -1 $CHROOT_DIR/boot/vmlinuz-* | sort -V | tail -n1) && cp $KERNEL_FILE $IMAGE_DIR/casper/vmlinuz
RUN INITRD_FILE=$(ls -1 $CHROOT_DIR/boot/initrd.img-* | sort -V | tail -n1) && cp $INITRD_FILE $IMAGE_DIR/casper/initrd
# Configuration du boot hybride BIOS + UEFI
RUN mkdir -p $IMAGE_DIR/boot/grub $IMAGE_DIR/EFI/BOOT
# Configuration GRUB pour BIOS
COPY boot/grub/grub.cfg $IMAGE_DIR/boot/grub/grub.cfg
# Configuration GRUB pour UEFI
COPY boot/grub/grub.cfg $IMAGE_DIR/EFI/BOOT/grub.cfg
# Créer le bootloader UEFI
RUN grub-mkstandalone \
    --format=x86_64-efi \
    --output=$IMAGE_DIR/EFI/BOOT/bootx64.efi \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=$IMAGE_DIR/boot/grub/grub.cfg"
# Copier le config.json par défaut dans l'image
COPY config.json $IMAGE_DIR/config.json


# Utiliser grub-mkrescue pour créer l'ISO hybride BIOS + UEFI
# Cette méthode est plus fiable que xorriso pour les ISO hybrides
ENTRYPOINT grub-mkrescue -o /output/$ISO_NAME $IMAGE_DIR
