#!/usr/bin/env zsh

cd "${0%/*}" || exit

DOTFILES=$(pwd)

echo "export DOTFILES=$DOTFILES" >./.dotfiles-dir
. ./.zsh.d/install.zsh
install_dotfiles $DOTFILES

cd - || exit
