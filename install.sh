#!/usr/bin/env bash


cd "${0%/*}" || exit

for file in .*; do
	[[ $file == *.git* || $file = "." || $file = ".." || $file = ".vscode" || $file == ".sonarlint" ]] && continue
	[[ -f ~/$file ]] && unlink ~/"$file"
	echo "linking $file -> ~/$file"
	ln -s "$PWD/$file" ~/"$file"
done

antibody bundle < ~/.zsh-plugins > ~/.zsh-plugins.sh

cd - || exit
