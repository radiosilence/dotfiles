# lig itself is started from .zshrc; this only applies inside it.
[[ -z $LIG_DISABLE && -n $LIG_TTY && $LIG_TTY == $TTY ]] || return

# Carries the popup to the remote shell, installing nothing there. With a
# remote command it is plain ssh, so scripts and git are unaffected.
alias ssh='lig ssh'
