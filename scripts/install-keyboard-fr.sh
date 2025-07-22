#!/bin/bash

apt update && apt install -y  console-setup keyboard-configuration || true

# Configurer le clavier français
echo 'XKBLAYOUT="fr"' > /etc/default/keyboard
echo 'XKBVARIANT=""' >> /etc/default/keyboard
echo 'XKBOPTIONS=""' >> /etc/default/keyboard
echo 'BACKSPACE="guess"' >> /etc/default/keyboard
setupcon

