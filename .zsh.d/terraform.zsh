autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C "$BREW_PREFIX/bin/terraform" terraform
