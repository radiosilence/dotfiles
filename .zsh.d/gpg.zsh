enable_gpg_ssh() {
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
}

enable_ssh_ssh() {
  eval $(ssh-agent)
}

if command -v gpg &>/dev/null; then
  gpg-connect-agent --quiet /bye >/dev/null 2>/dev/null
  gpg-agent --daemon --quiet --enable-ssh-support >/dev/null 2>&1

  export GPG_TTY=$(tty)

  enable_gpg_ssh
else
  enable_ssh_ssh
fi
