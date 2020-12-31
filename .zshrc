# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  . "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

#!/usr/bin/env zsh
setopt NULL_GLOB

is_cmd() {
  command -v $1 &>/dev/null
}

is_macos() {
  [ -d /Library ]
}

if [ -f ~/.dotfiles-dir ]; then
  . ~/.dotfiles-dir
else
  echo "\$DOTFILES not set, please run install again"
fi

fpath=($DOTFILES_DIR, $fpath)

for config (~/.zsh.d/*.zsh) . $config

if [ -d ~/.zsh.d.local ]; then
  for config (~/.zsh.d.local/*.zsh) . $config
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
if [ -f ~/.p10k.zsh ]; then
   . ~/.p10k.zsh
  fi

