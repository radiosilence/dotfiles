#!/usr/bin/env zsh

setopt extendedglob

for file in .*~.git
do
	echo "unlinking $file"
	unlink $HOME/$file || "$file didn't exist"
	echo "linking $PWD/$file -> $file"
	ln -s $PWD/$file $HOME/$file
done

