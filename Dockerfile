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

# Créer le répertoire de travail
#WORKDIR $SRC_DIR


# Créer les répertoires de build
#RUN mkdir -p $IMAGE_DIR/casper $IMAGE_DIR/boot/grub $IMAGE_DIR/EFI/BOOT

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
# Copier les fichiers systemd
COPY scripts/*.service $CHROOT_DIR/etc/systemd/system/
# Copier les scripts d'installation des fonctionnalités
COPY scripts/install-*.sh $CHROOT_DIR/root/
RUN chmod +x $CHROOT_DIR/root/install-*.sh
# Copier les scripts de démarrage automatique appelés par l'entrypoint
COPY scripts/run-*.sh $CHROOT_DIR/usr/local/bin/
RUN chmod +x $CHROOT_DIR/usr/local/bin/run-*.sh
# Copier les scripts de gestion des utilisateurs
COPY scripts/add-user-*.sh $CHROOT_DIR/usr/local/bin/
RUN chmod +x $CHROOT_DIR/usr/local/bin/add-user-*.sh
# Copier le dossier web pour le dashboard nginx
COPY web/ $CHROOT_DIR/var/www/html/
# Copier le fichier de personnalisation de l'ISO
COPY config.env $CHROOT_DIR/config.env


########################################
#                                      #
# installation des paquets dans l'ISO  #
#                                      #
########################################
# Installation des paquets essentiels pour un live system
RUN chroot $CHROOT_DIR apt update && chroot $CHROOT_DIR apt install -y \
    software-properties-common \
    initramfs-tools \
    casper \
    linux-image-generic \
    linux-image-virtual \
    linux-tools-virtual \
    linux-cloud-tools-virtual \
    laptop-detect \
    os-prober
# Installation des outils de base pour serveur
RUN chroot $CHROOT_DIR apt install -y \
    curl \
    wget \
    nano \
    vim \
    htop \
    net-tools \
    iputils-ping \
    cron \
    rsync
# Ajoute le paquet dos2unix pour la lecture du config.env
RUN chroot $CHROOT_DIR add-apt-repository -y universe && \
    chroot $CHROOT_DIR apt update && \
    chroot $CHROOT_DIR apt install -y dos2unix

################################################
#                                              #
# installation des fonctionnalités dans l'ISO  #
#                                              #
################################################    
# Appeler tous les scripts d'installation des fonctionnalités
RUN chroot $CHROOT_DIR /root/install-keyboard-fr.sh
RUN chroot $CHROOT_DIR /root/install-network.sh
RUN chroot $CHROOT_DIR /root/install-ssh.sh
RUN chroot $CHROOT_DIR /root/install-docker.sh
RUN chroot $CHROOT_DIR /root/install-rclone.sh

#RUN umount $CHROOT_DIR/dev
# Copier et activer l'entrypoint pour le démarrage automatique des services
COPY scripts/entrypoint.sh $CHROOT_DIR/usr/local/bin/entrypoint.sh
RUN chmod +x $CHROOT_DIR/usr/local/bin/entrypoint.sh
RUN chroot $CHROOT_DIR systemctl enable entrypoint.service


#########################################
#                                       #
# Création de l'image ISO personnalisée #
#                                       #
#########################################
# Générer l'initramfs
RUN chroot $CHROOT_DIR update-initramfs -u
# Créer l'image squashfs contenant les fichiers du chroot
RUN mkdir -p $IMAGE_DIR/casper
RUN mksquashfs $CHROOT_DIR $IMAGE_DIR/casper/filesystem.squashfs -e boot
# Copier les fichiers kernel et initrd (prendre le plus récent)
RUN KERNEL_FILE=$(ls -1 $CHROOT_DIR/boot/vmlinuz-* | sort -V | tail -n1) && cp $KERNEL_FILE $IMAGE_DIR/casper/vmlinuz
RUN INITRD_FILE=$(ls -1 $CHROOT_DIR/boot/initrd.img-* | sort -V | tail -n1) && cp $INITRD_FILE $IMAGE_DIR/casper/initrd
# Configuration du boot hybride BIOS + UEFI
RUN mkdir -p $IMAGE_DIR/boot/grub $IMAGE_DIR/EFI/BOOT
# Configuration GRUB pour BIOS
COPY scripts/grub.cfg $IMAGE_DIR/boot/grub/grub.cfg
# Configuration GRUB pour UEFI
COPY scripts/grub.cfg $IMAGE_DIR/EFI/BOOT/grub.cfg
# Créer le bootloader UEFI
RUN grub-mkstandalone \
    --format=x86_64-efi \
    --output=$IMAGE_DIR/EFI/BOOT/bootx64.efi \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=$IMAGE_DIR/boot/grub/grub.cfg"
# Supprimer les fichiers cloud-init (plus nécessaires)
# RUN rm -rf $IMAGE_DIR/nocloud

# Utiliser grub-mkrescue pour créer l'ISO hybride BIOS + UEFI
# Cette méthode est plus fiable que xorriso pour les ISO hybrides
ENTRYPOINT grub-mkrescue -o /output/$ISO_NAME $IMAGE_DIR
