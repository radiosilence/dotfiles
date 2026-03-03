# Broot configuration
command -v broot >/dev/null || return

# Source broot launcher script (provides `br` function)
[[ -f ~/.config/broot/launcher/bash/br ]] && source ~/.config/broot/launcher/bash/br
