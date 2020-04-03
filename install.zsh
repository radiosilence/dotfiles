#!/usr/bin/env zsh


cd "${0%/*}" || exit


for file in .*; do
	[[ $file == *.git* || $file = "." || $file = ".." || $file = ".vscode" || $file == ".sonarlint" ]] && continue
	[[ -f ~/$file ]] && unlink ~/$file
	if [ -v SSH_TTY ]; then
		if [ $file = ".tmux.conf "]; then
			echo "skipping .tmux.conf because on ssh"
			continue
		fi
	fi
	echo "linking $file -> ~/$file"
	[[ ! -d ~/$file ]] && ln -s "$PWD/$file" ~/"$file"
done

antibody bundle < ~/.zsh-plugins > ~/.zsh-plugins.sh

mkdir -p ~/.config/kitty
[[ -f ~/.config/kitty/kitty.conf ]] && unlink ~/.config/kitty/kitty.conf
ln -s ~/.dotfiles/kitty.conf ~/.config/kitty/kitty.conf

cd - || exit
