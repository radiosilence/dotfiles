if [ -e ~/.zgenom/zgenom.zsh ]; then
  . ~/.zgenom/zgenom.zsh
fi

if is_cmd zgenom; then
  export ZGEN_RESET_ON_CHANGE=($DOTFILES/.zsh.d/05-zgenom.zsh)
  zgenom autoupdate

  if ! zgenom saved; then
    zgenom loadall <<EOPLUGINS
    Tarrasch/zsh-bd
    zsh-users/zsh-completions
    zsh-users/zsh-autosuggestions . develop
    zsh-users/zsh-history-substring-search
    zsh-users/zsh-syntax-highlighting
    ryutok/rust-zsh-completions
    marlonrichert/zsh-autocomplete
EOPLUGINS

    zgenom save
  fi
fi
