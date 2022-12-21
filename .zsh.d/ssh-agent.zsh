if [[ -f "$ssh_env_cache" ]]; then
    zmodload zsh/net/socket
    if [[ -S "$SSH_AUTH_SOCK" ]] && zsocket "$SSH_AUTH_SOCK" 2>/dev/null; then
        return 0
    fi
fi

eval $(ssh-agent) >/dev/null
ssh-add 2>/dev/null
