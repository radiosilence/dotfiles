#
# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi
autoload -U promptinit; promptinit
prompt pure
# Customize to your needs...
#
export PATH="/usr/local/opt/coreutils/libexec/gnubin:/usr/local/bin:$PATH"
export PATH="$HOME/.nodenv/shims:$PATH"

export GOPATH=$(go env GOPATH)

export EDITOR=vim

setopt clobber
setopt no_share_history
setopt interactivecomments

alias 'youtube-dl=noglob youtube-dl '
alias 'curl=noglob curl '
alias 'http=noglob http '
alias 'll=ls -lh --color'
alias 'la=ls -lha --color'

alias mntwrk='hdiutil attach -mountpoint ~/Workspace ~/_Workspace.sparsebundle'
alias npmpubjc='npm publish --userconfig ~/.npmrc-jc'
alias brewski='brew update && brew upgrade && brew cleanup; brew doctor; brew prune'
export PATH=$PATH:~/.local/bin

# tabtab source for serverless package
# uninstall by removing these lines or running `tabtab uninstall serverless`
[[ -f /Users/james/Workspace/lml/api-custom-authorizers/node_modules/tabtab/.completions/serverless.zsh ]] && . /Users/james/Workspace/lml/api-custom-authorizers/node_modules/tabtab/.completions/serverless.zsh
# tabtab source for sls package
# uninstall by removing these lines or running `tabtab uninstall sls`
[[ -f /Users/james/Workspace/lml/api-custom-authorizers/node_modules/tabtab/.completions/sls.zsh ]] && . /Users/james/Workspace/lml/api-custom-authorizers/node_modules/tabtab/.completions/sls.zsh

alias 'https-server=http-server --ssl --cert ~/Workspace/localhost.pem --key ~/Workspace/localhost.pem'
