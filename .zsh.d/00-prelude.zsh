. ~/.dotfiles-dir
. $(dirname 0)/../common.zsh

# opts
setopt no_share_history
setopt interactivecomments

# autoloads
autoload -U add-zsh-hook
# zstyle
zstyle '*:compinit' arguments -D -i -u -C -w

# editor
# if is_cmd code-insiders; then
#   export EDITOR="code-insiders --wait"
# e
if is_cmd hx; then
  export EDITOR="hx"
elif is_cmd code; then
  export EDITOR="code --wait"
else
  export EDITOR=vim
fi

# it is colourful damnit
export CLICOLOR=1

export WORDCHARS=''
