#!/usr/bin/env zsh
for file in $(print .*~.git)
do
	echo $file
	# unlink $HOME/$file
	# ln -s $PWD/$file $HOME/$file
done

