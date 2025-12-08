# /etc/bash.bashrc - configuration globale pour tous les utilisateurs

# === Activation des couleurs et alias globaux ===
if [ -x /usr/bin/dircolors ]; then
    eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias ll='ls -alF --color=auto'
    alias la='ls -A --color=auto'
    alias l='ls -CF --color=auto'
fi

# === Historique plus pratique ===
HISTSIZE=1000
HISTFILESIZE=2000
HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# === Prompt coloré (rouge pour root, vert pour user) ===
if [ "$EUID" -eq 0 ]; then
    # Rouge pour root
    PS1="\[\e[1;31m\]\u@\h\[\e[0m\]:\[\e[1;37m\]\w\[\e[0m\]\$ "
else
    # Vert pour utilisateur normal
    PS1="\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;37m\]\w\[\e[0m\]\$ "
fi

# === Comportement interactif seulement ===
case $- in
    *i*) ;;
      *) return;;
esac

# === Completion Bash ===
if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi
