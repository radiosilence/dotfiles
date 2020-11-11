gpg-connect-agent --quiet /bye >/dev/null 2>/dev/null
gpg-agent --daemon --quiet --enable-ssh-support >/dev/null 2>&1

export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
export GPG_TTY=$(tty)
