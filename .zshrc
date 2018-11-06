# opts
setopt clobber
setopt no_share_history
setopt interactivecomments

# config
ZSH_AUTOSUGGEST_USE_ASYNC=false
NVM_AUTO_USE=true
NVM_LAZY_LOAD=true
PURE_PROMPT_SYMBOL='→ '

# binds
bindkey -e
bindkey '[C' forward-word
bindkey '[D' backward-word

# editor
export EDITOR=vim

# zplug
export ZPLUG_HOME=/usr/local/opt/zplug
source $ZPLUG_HOME/init.zsh

zplug "mafredri/zsh-async", from:"github", use:"async.zsh"
zplug "sindresorhus/pure", use:pure.zsh, from:github, as:theme
zplug "modules/directory", from:prezto
zplug "modules/completion", from:prezto
zplug "modules/ssh", from:prezto
zplug "zsh-users/zsh-autosuggestions"
zplug "zsh-users/zsh-syntax-highlighting", defer:2
zplug "zsh-users/zsh-history-substring-search"
zplug "lukechilds/zsh-nvm"
zplug "erikced/zsh-pyenv-lazy-load"

if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

zplug load

# path
PATH="/usr/local/bin:$PATH"
PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"
PATH="/usr/local/opt/gnu-tar/libexec/gnubin:$PATH"
PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
PATH="/usr/local/opt/gnu-getopt/bin:$PATH"
PATH="$HOME/.local/bin:$PATH"
PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
PATH="$HOME/Library/Android/sdk/tools/bin:$PATH"
PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
PATH="$HOME/.nodenv/shims:$PATH"

# aliases
alias 'youtube-dl=noglob youtube-dl '
alias 'curl=noglob curl '
alias 'http=noglob http '
alias 'll=ls -lh --color '
alias 'la=ls -lha --color '
alias 'ip=ip -c -br '
alias brewski='brew update && brew upgrade && brew cleanup; brew doctor; brew prune'

# go
if [ -x "$(which go)" ]; then
  GOPATH=$(go env GOPATH)
  PATH="$GOPATH/bin:$PATH"
fi

# export path
export PATH