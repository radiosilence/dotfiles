# Load custom functions
fpath=(~/.config/zsh/functions $fpath)
autoload -Uz ~/.config/zsh/functions/*(.:t)
