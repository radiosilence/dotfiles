#!/usr/bin/env zsh

cd "${0%/*}" || exit

DOTFILES=$(pwd)

echo "export DOTFILES=$DOTFILES" >./.dotfiles-dir

for file in .*; do
	[[ $file == *.git* || $file = "." || $file = ".." || $file = ".vscode" || $file == ".sonarlint" ]] && continue
	[[ -f ~/$file ]] && unlink ~/$file
	if [ -v SSH_TTY ] && [ $file = ".tmux.conf" ]; then
		echo "skipping .tmux.conf because on ssh"
		continue
	fi
	echo "linking $file -> ~/$file"
	[[ ! -d ~/$file ]] && ln -s "$PWD/$file" ~/"$file"
done

antibody bundle <~/.zsh-plugins >~/.zsh-plugins.sh

mkdir -p ~/.config/kitty
[[ -f ~/.config/kitty/kitty.conf ]] && unlink ~/.config/kitty/kitty.conf
ln -s "$DOTFILES/kitty.conf" ~/.config/kitty/kitty.conf

cd - || exit
