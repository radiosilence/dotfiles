#!/usr/bin/env zsh

bindkey -e

# opts
setopt clobber
set +o noclobber
setopt no_share_history
setopt interactivecomments

# autoloads
autoload -Uz compinit
autoload -U add-zsh-hook

# config
ZSH_AUTOSUGGEST_USE_ASYNC=false
#
PURE_PROMPT_SYMBOL='→'

# binds
bindkey "\e[3~" delete-char

# prezto modules config
zstyle ':prezto:module:gnu-utility' prefix 'g'
zstyle ':prezto:module:ssh:load' identities 'id_ed25519' 'id_rsa' 'id_github'

# editor
export EDITOR=vim

# antibody
update_plugins() {
  rm $HOME/.zsh-plugins.sh || echo "no plugins found"
  antibody bundle < $HOME/.zsh-plugins > $HOME/.zsh-plugins.sh
  source $HOME/.zsh-plugins.sh
}

source $HOME/.zsh-plugins.sh

# pure power
PURE_POWER_MODE=fancy
source ~/.purepower

# powerlevel9k
POWERLEVEL9K_DIR_DEFAULT_FOREGROUND='grey58'
POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND='grey58'
POWERLEVEL9K_VCS_MODIFIED_FOREGROUND='grey42'
POWERLEVEL9K_VCS_CLEAN_FOREGROUND='grey42'

# completions
typeset -i updated_at=$(date +'%j' -r ~/.zcompdump 2>/dev/null || stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)
if [ $(date +'%j') != $updated_at ]; then
  compinit -i
else
  compinit -C -i
fi

# path
PATH="/usr/local/bin:$PATH"
PATH="/usr/local/sbin:$PATH"
PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
PATH="$HOME/Library/Android/sdk/tools/bin:$PATH"
PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
PATH="$(ruby -e 'print "%s/bin:%s/bin" % [Gem.user_dir, Gem.dir]'):$PATH"
PATH="$HOME/.cargo/bin:$PATH"

# android sdk
export ANDROID_HOME="$HOME/Library/Android/sdk"

# aliases
alias 'youtube-dl=noglob youtube-dl '
alias 'curl=noglob curl '
alias 'http=noglob http '
alias 'll=ls -lh --color '
alias 'la=ls -lha --color '
alias 'ip=ip -c -br '
alias brewski='brew update && brew upgrade && brew cleanup; brew doctor'

# export path
export PATH

# sdkman
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# asdf
source $HOME/.asdf/asdf.sh
source $HOME/.asdf/completions/asdf.bash

# useful things

alias 'zoom=sudo launchctl remove com.cylance.agent_service'
