#
# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi
autoload -U promptinit; promptinit
prompt pure
# Customize to your needs...
#

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
export PATH="$HOME/.nodenv/shims:$PATH"
export EDITOR=vim

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

setopt clobber
setopt no_share_history
setopt interactivecomments

alias 'youtube-dl=noglob youtube-dl '
alias 'curl=noglob curl '
alias 'http=noglob http '
alias 'll=ls -lh --color '
alias 'la=ls -lha --color '
alias 'ip=ip -c -br '

alias mntwrk='hdiutil attach -mountpoint ~/Workspace ~/_Workspace.sparsebundle'
alias npmpubjc='npm publish --userconfig ~/.npmrc-jc'
alias brewski='brew update && brew upgrade && brew cleanup; brew doctor; brew prune'

alias 'https-server=http-server --ssl --cert ~/Workspace/localhost.pem --key ~/Workspace/localhost.pem'

export GOPATH=$(go env GOPATH)
export PATH="$GOPATH/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

GOPATH=$(go env GOPATH)
PATH="$GOPATH/bin:$PATH"

alias hrun=pyenv exec honcho -f etc/environments/development/procfile -e etc/environments/development/env run

eval "$(pyenv init -)"
