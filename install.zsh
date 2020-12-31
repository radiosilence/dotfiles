#!/usr/bin/env zsh

(
  cd "${0%/*}" || exit
  DOTFILES=$(pwd)
  git pull
  echo "export DOTFILES=$DOTFILES" >~/.dotfiles-dir
  . ./.zsh.d/install.zsh
  install_dotfiles $DOTFILES
)
