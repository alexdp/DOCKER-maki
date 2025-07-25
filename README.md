# ISO Builder

Ce projet permet de générer automatiquement une image ISO Ubuntu 24.04 (Noble) contenant :
- Docker installé et activé
- Portainer pour la gestion des conteneurs
- Samba pour le partage de fichiers
- SSH configuré pour l'accès distant
- File Browser et Jellyfin pré-téléchargés
- Configuration automatique au démarrage


## Lancer le build

DOCKER_BUILDKIT=0 docker compose build && docker compose up


L'image ISO se trouve dans le répertoire output