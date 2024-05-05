now() {
  date +%s.%N
}

# global_start=$(now)

time_from() {
  diff=$(($(now) - $1))
  in_ms=$(($diff * 1000))
  echo $in_ms
}

setopt NULL_GLOB

export ZSH_ASDF_DIRENV_LIBONLY=true

if [ -e ~/.dotfiles-dir ]; then
  . ~/.dotfiles-dir
else
  echo "\$DOTFILES not set, please run install again"
fi

fpath=($DOTFILES, $fpath)

for config in ~/.zsh.d/*.zsh; do
  . $config
  # word="shims"
  # string=$PATH
  # test "${string#*$word}" != "$string" && echo "post $config: $word found in path"
done

if [ -d ~/.zsh.d.local ]; then
  for config in ~/.zsh.d.local/*.zsh; do
    . $config
  done
fi

export STARSHIP_CONFIG=~/.starship.toml
eval "$(starship init zsh)"
# OPS config
export OPS_DIR="$HOME/.ops"
export PATH="$HOME/.ops/bin:$PATH"
source "$HOME/.ops/scripts/bash_completion.sh"
autoload bashcompinit
