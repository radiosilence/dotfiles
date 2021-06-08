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

if [ -e ~/.dotfiles-dir ]; then
  . ~/.dotfiles-dir
else
  echo "\$DOTFILES not set, please run install again"
fi

fpath=($DOTFILES, $fpath)

for config in ~/.zsh.d/*.zsh; do
  # start=$(now)
  . $config
  # echo "[$(time_from $start)] loaded $config"
done

if [ -d ~/.zsh.d.local ]; then
  for config in ~/.zsh.d.local/*.zsh; do
    . $config
  done
fi

export STARSHIP_CONFIG=~/.starship.toml
eval "$(starship init zsh)"

# global_end=$(date +%s.%N)
# echo "TOTAL TIME $(time_from $global_start)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
