if [ -e ~/.zgenom/zgenom.zsh ]; then
  . ~/.zgenom/zgenom.zsh
fi

if is_cmd zgenom; then
  export ZGEN_RESET_ON_CHANGE=($DOTFILES/.zsh.d/05-zgenom.zsh)
  zgenom autoupdate

  if ! zgenom saved; then
    # zgenom load mafredri/zsh-async
    zgenom load Tarrasch/zsh-bd
    zgenom load zsh-users/zsh-completions
    zgenom load zsh-users/zsh-autosuggestions . develop
    zgenom load zsh-users/zsh-history-substring-search
    zgenom load zsh-users/zsh-syntax-highlighting
    zgenom load ryutok/rust-zsh-completions
    zgenom load marlonrichert/zsh-autocomplete
    zgenom load redxtech/zsh-asdf-direnv
    # zgenom load wfxr/forgit
    # zgenom load ptavares/zsh-direnv

    zgenom save
  fi
fi
