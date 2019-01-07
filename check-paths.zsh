#!/bin/zsh
paths=("${(@s/:/)${PATH}}")
for path in $paths; do
  [ -d "$path" ] || echo "\e[0;31mDirectory $path does not exist!\e[0m"
done
