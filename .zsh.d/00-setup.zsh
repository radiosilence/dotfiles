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

# it is colourful damnit
export CLICOLOR=1