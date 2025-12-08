# Serveur de stockage "maison" basé sur Ubuntu

Ce projet est une alternative aux NAS du commerce à travers une distribution Linux à mettre une clé USB "live". L'idée de ce projet est de faire en sorte que vos disques durs ne contiennent que vos données. Vous pouvez y accéder depuis un autre Linux "live" ou un autre système de façon très simple. Aucun risque de corrompre vos système, il suffit de redémarrer votre PC pour que la clé USB recharge un système tout neuf.

Ce projet permet de générer automatiquement une image ISO Ubuntu 24.04 (Noble) contenant :
- Portail web d'accès à tous les services (http://\[IP\])
- FileBrowser pour l'accès web aux fichiers
- Samba pour le partage de fichiers sous Windows
- PiGallery2 pour visionner les photos
- JellyFin pour visionner les vidéos
- Kopia pour gérér des sauvegardes sur un espace à part
- Rclone (accessible en ligne de commande) pour monter des volumes cloud (Google Drive, OneDrive, DropBox, ...)
- SSH configuré pour l'accès distant (avec Shellinabox pour un accès simplifié via le navigateur internet)
- Docker pour le déploiement simple d'applications tierces (avec stockage des données sur le premier volume monté ou suivant la configuration "storage location" définie dans config.json)


# Utilisation

Transférer l'ISO sur une clé USB avec un outil laissant la clé lisible sous Microsoft Windows afin d'y déposer un fichier config.json pour paramétrer l'ISO tel que balenaEtcher.

# Configuration

La configuration est automatique au démarrage : 
- Détection de la première carte réseau filaire et IP automatique (DHCP)
- Montage automatique de tous les volumes disques dans /mnt

Selon le cas d'usage (paramétrage WIFI par exemple), il est possible de poser à la racine de la clé USB un fichier config.json à paramétrer selon le modèle suivant : 

````
{
  "hostname": "maki",
  "network": {
    "type": "wifi|ethernet",
    "ssid": "home_wifi_name",
    "psk": "wifi_password",
    "dhcp": false,
    "static": {
      "address": "192.168.1.100",
      "netmask": "255.255.255.0",
      "gateway": "192.168.1.1",
      "dns": "8.8.8.8"
    }
  },
  "storage": {
    "location": "auto|/mnt/sda|/mnt/sdb1"
  },
  "users": [
    {"name": "demo", "password": "demo", "admin": true},
    {"name": "guest", "password": "guest"},
    {"name": "open_guest"},
    {"name": "ubuntu", "admin": true}
  ]
}
````



# Reconstruire l'ISO depuis les sources

- docker compose build pour préparer l'image
- docker compose up pour générer l'ISO dans ./output
