if is_cmd gpg-connect-agent; then
  export GPG_TTY=$(tty)
  gpg-connect-agent updatestartuptty /bye >/dev/null
  unset SSH_AGENT_PID
  export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

  gpg-switch-yubikey() {
    gpg-connect-agent "scd serialno" "learn --force" /bye
  }
fi
