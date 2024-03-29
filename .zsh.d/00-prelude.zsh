is_cmd() {
  command -v $1 &>/dev/null
}

is_macos() {
  [ -d /Library ]
}

join_by() {
  local d=$1
  shift
  local f=$1
  shift
  printf %s "$f" "${@/#/$d}"
}

# opts
setopt no_share_history
setopt interactivecomments

# autoloads
autoload -U add-zsh-hook
# zstyle
zstyle '*:compinit' arguments -D -i -u -C -w

# fix for sheldon

zstyle ':zephyr:plugin:completion' manual 'yes'

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
