# ISO Builder

Ce projet permet de générer automatiquement une image ISO Ubuntu 24.04 (Noble) contenant :
- Docker installé et activé
- Portainer pour la gestion des conteneurs
- Samba pour le partage de fichiers
- SSH configuré pour l'accès distant
- File Browser et Jellyfin pré-téléchargés
- Configuration automatique au démarrage


## Lancer le build

- Avec cache de build : docker compose build && docker compose up
- Sans cache de build : docker compose up -build

L'image ISO se trouve dans le répertoire output