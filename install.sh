#!/usr/bin/env bash


cd "${0%/*}" || exit

for file in .*; do
	[[ $file == *.git* || $file = "." || $file = ".." || $file = ".vscode" || $file == ".sonarlint" ]] && continue
	[[ -f "$HOME/$file" ]] && unlink "$HOME/$file"
	echo "linking $file -> $HOME/$file"
	ln -s "$PWD/$file" "$HOME/$file"
done

antibody bundle < "$HOME/.zsh-plugins" > "$HOME/.zsh-plugins.sh"

cd - || exit
