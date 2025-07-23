#!/bin/bash

echo "=== Script entrypoint lancé à $(date) ===" >> /var/log/entrypoint.log

# Démarrage des fonctionnalités
echo "Démarrage de la configuration réseau..." >> /var/log/entrypoint.log
/usr/local/bin/run-network.sh || echo "Erreur lors de la configuration du réseau" >> /var/log/entrypoint.log

echo "Démarrage du montage des disques..." >> /var/log/entrypoint.log
/usr/local/bin/run-mount.sh || echo "Erreur lors du montage des disques" >> /var/log/entrypoint.log

echo "Démarrage de la création des répertoires..." >> /var/log/entrypoint.log
source /usr/local/bin/run-directory.sh || echo "Erreur lors de la création des répertoires" >> /var/log/entrypoint.log

echo "Démarrage de Docker..." >> /var/log/entrypoint.log
/usr/local/bin/run-docker.sh || echo "Erreur lors du démarrage de Docker" >> /var/log/entrypoint.log

echo "Démarrage de Rclone..." >> /var/log/entrypoint.log
/usr/local/bin/run-rclone.sh || echo "Erreur lors du démarrage de Rclone" >> /var/log/entrypoint.log

echo "=== Fin du script entrypoint à $(date) ===" >> /var/log/entrypoint.log
