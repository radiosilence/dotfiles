#!/usr/bin/env zsh

# opts
setopt clobber
setopt no_share_history
setopt interactivecomments

# config
ZSH_AUTOSUGGEST_USE_ASYNC=false
NVM_AUTO_USE=true
NVM_LAZY_LOAD=true
PURE_PROMPT_SYMBOL='→'

# binds
bindkey "\e[3~" delete-char

# prezto config
zstyle ':prezto:module:gnu-utility' prefix 'g'
zstyle ':prezto:module:ssh:load' identities 'id_ed25519' 'id_rsa2' 'id_github'
zstyle ':prezto:module:syntax-highlighting' highlighters 'main' 'brackets' 'pattern' 'line' 'cursor' 'root'

# editor
export EDITOR=vim

# antibody
source <(antibody init)

antibody bundle < "$HOME/.zsh-plugins"

# antibody bundle mafredri/zsh-async
# # antibody bundle robbyrussell/oh-my-zsh folder:plugins/completion
# # antibody bundle robbyrussell/oh-my-zsh folder:plugins/directory
# # antibody bundle robbyrussell/oh-my-zsh folder:plugins/editor
# antibody bundle robbyrussell/oh-my-zsh folder:plugins/git
# antibody bundle robbyrussell/oh-my-zsh folder:plugins/gnu-utils
# antibody bundle robbyrussell/oh-my-zsh folder:plugins/history
# antibody bundle robbyrussell/oh-my-zsh folder:plugins/ssh
# antibody bundle robbyrussell/oh-my-zsh folder:plugins/tmux
# antibody bundle lukechilds/zsh-nvm

# antibody bundle sindresorhus/pure
# antibody bundle zsh-users/zsh-autosuggestions
# antibody bundle zsh-users/zsh-syntax-highlighting

# path
PATH="/usr/local/bin:$PATH"
PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
PATH="$HOME/Library/Android/sdk/tools/bin:$PATH"
PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
PATH="$(ruby -e 'print "%s/bin:%s/bin" % [Gem.user_dir, Gem.dir]'):$PATH"
PATH="$HOME/.cargo/bin:$PATH"

# aliases
alias 'youtube-dl=noglob youtube-dl '
alias 'curl=noglob curl '
alias 'http=noglob http '
alias 'll=ls -lh --color '
alias 'la=ls -lha --color '
alias 'ip=ip -c -br '
alias brewski='brew update && brew upgrade && brew cleanup; brew doctor'

# go
if [ -x "$(which go)" ]; then
  GOPATH=$(go env GOPATH)
  PATH="$GOPATH/bin:$PATH"
fi

# java
[[ -x "/usr/libexec/java_home" ]] && export JAVA_HOME="$(/usr/libexec/java_home -v 1.8)"

# export path
export PATH

# sdkman
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
