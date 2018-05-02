#!/bin/zsh

for file in .*
do
	unlink $HOME/$file
	ln -s $file $HOME/$file
done

