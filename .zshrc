# opts
setopt clobber
setopt no_share_history
setopt interactivecomments

# config
ZSH_AUTOSUGGEST_USE_ASYNC=false
NVM_AUTO_USE=true
NVM_LAZY_LOAD=false
PURE_PROMPT_SYMBOL='→'

# binds
bindkey "\e[3~" delete-char

# prezto config
zstyle ':prezto:module:editor' key-bindings 'emacs'
zstyle ':prezto:module:editor' dot-expansion 'yes'
zstyle ':prezto:module:gnu-utility' prefix 'g'
zstyle ':prezto:module:ssh:load' identities 'id_ed25519' 'id_rsa2' 'id_github'
zstyle ':prezto:module:syntax-highlighting' highlighters 'main' 'brackets' 'pattern' 'line' 'cursor' 'root'

# editor
export EDITOR=vim

# zplug
export ZPLUG_HOME=/usr/local/opt/zplug
source $ZPLUG_HOME/init.zsh

zplug "mafredri/zsh-async", from:"github", use:"async.zsh"
zplug "intelfx/pure", use:pure.zsh, from:github, as:theme
zplug "modules/editor", from:prezto
zplug "modules/git", from:prezto
zplug "modules/directory", from:prezto
zplug "modules/completion", from:prezto
zplug "modules/history", from:prezto
zplug "modules/ssh", from:prezto
zplug "modules/gnu-utility", from:prezto
zplug "modules/tmux", from:prezto
zplug "lukechilds/zsh-nvm"
zplug "zsh-users/zsh-autosuggestions"
zplug "zsh-users/zsh-syntax-highlighting", defer:2
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
PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
PATH="$HOME/Library/Android/sdk/tools/bin:$PATH"
PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
PATH="$(ruby -e 'print "%s/bin:%s/bin" % [Gem.user_dir, Gem.dir]'):$PATH"

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

# java
export JAVA_HOME="$(/usr/libexec/java_home -v 1.8)"

# export path
export PATH
