[[ -d ~/.config/zsh/functions ]] || return

fpath=(~/.config/zsh/functions $fpath)
autoload -Uz ~/.config/zsh/functions/*(.:t)
