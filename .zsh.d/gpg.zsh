enable_ssh_ssh() {
  eval $(ssh-agent)
}

if command -v gpg &>/dev/null; then
  gpg-connect-agent --quiet /bye >/dev/null 2>/dev/null
  gpg-agent --daemon --quiet --enable-ssh-support >/dev/null 2>&1
  export GPG_TTY=$(tty)

else
  enable_ssh_ssh
fi

# You must set IdentityAgent like so...
# Host *
#     ServerAliveInterval 120
#     TCPKeepAlive yes
#     IdentityAgent ~/.gnupg/S.gpg-agent.ssh
