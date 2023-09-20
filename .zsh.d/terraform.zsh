if is_cmd terraform; then
    complete -o nospace -C "$BREW_PREFIX/bin/terraform" terraform
fi
