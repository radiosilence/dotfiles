# LSD (better ls) configuration
command -v lsd >/dev/null || return

alias lsd='lsd -A --color=always --icon=always --hyperlink=auto'
alias l='lsd'
alias ls='lsd'
alias ll='lsd -l'
alias tree='lsd --tree'
