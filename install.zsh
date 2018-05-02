#!/bin/zsh

for file in .*
do
	unlink $HOME/$file
	ln -s $PWD/$file $HOME/$file
done

