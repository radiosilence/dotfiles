# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   . "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

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
# . ~/.zsh.d/00-prelude.zsh
# . ~/.zsh.d/01-path.zsh
# . ~/.zsh.d/02-asdf.zsh
# . ~/.zsh.d/03-brew.zsh
# . ~/.zsh.d/04-fzf.zsh
# . ~/.zsh.d/05-zgenom.zsh
# . ~/.zsh.d/90-alias.zsh
# . ~/.zsh.d/90-sdks.zsh
# . ~/.zsh.d/98-completions.zsh
# . ~/.zsh.d/99-clobber.zsh
# . ~/.zsh.d/99-ls.zsh
# . ~/.zsh.d/aws.zsh
# . ~/.zsh.d/beet.zsh
# . ~/.zsh.d/directory.zsh
# . ~/.zsh.d/git.zsh
# . ~/.zsh.d/gpg.zsh
# . ~/.zsh.d/history-substring-search.zsh
# . ~/.zsh.d/history.zsh
# . ~/.zsh.d/install.zsh
# . ~/.zsh.d/nix.zsh
# . ~/.zsh.d/p10k.zsh
# . ~/.zsh.d/rust.zsh
# . ~/.zsh.d/tabtab.zsh
# . ~/.zsh.d/updates.zsh
# . ~/.zsh.d/yarn.zsh

if [ -d ~/.zsh.d.local ]; then
  for config in ~/.zsh.d.local/*.zsh; do
    . $config
  done
fi

# global_end=$(date +%s.%N)
# echo "TOTAL TIME $(time_from $global_start)"
