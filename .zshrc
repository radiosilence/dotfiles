# zplug
export ZPLUG_HOME=/usr/local/opt/zplug
source $ZPLUG_HOME/init.zsh

zplug "mafredri/zsh-async", from:"github", use:"async.zsh"

zplug "modules/prompt", from:prezto
zplug "modules/git", from:prezto
zplug "modules/history", from:prezto
zplug "modules/directory", from:prezto
zplug "modules/completion", from:prezto
zplug "modules/ssh", from:prezto
zplug "modules/autosuggestions", from:prezto
zplug "k4rthik/git-cal", as:command

zplug "zsh-users/zsh-syntax-highlighting", defer:2

if ! zplug check; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

zplug load

# prompt
prompt pure
PURE_PROMPT_SYMBOL='→ '

# opts
setopt clobber
setopt no_share_history
setopt interactivecomments

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

# vim
export EDITOR=vim

# nvm
export NVM_DIR="$HOME/.nvm"
function load_nvm() {
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
}

async_start_worker nvm_worker -n
async_register_callback nvm_worker load_nvm
async_job nvm_worker sleep 0.1


# aliases
alias 'youtube-dl=noglob youtube-dl '
alias 'curl=noglob curl '
alias 'http=noglob http '
alias 'll=ls -lh --color '
alias 'la=ls -lha --color '
alias 'ip=ip -c -br '
alias brewski='brew update && brew upgrade && brew cleanup; brew doctor; brew prune'

# go
GOPATH=$(go env GOPATH)
PATH="$GOPATH/bin:$PATH"

# pyenv
[ -x "$(which pyenv)" ] && eval "$(pyenv init -)"

# export path
export PATH