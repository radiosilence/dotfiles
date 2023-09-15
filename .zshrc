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

# global_end=$(date +%s.%N)
# echo "TOTAL TIME $(time_from $global_start)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/jc/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
