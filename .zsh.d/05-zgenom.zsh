if [ -e ~/.zgenom/zgenom.zsh ]; then
  . ~/.zgenom/zgenom.zsh
fi

if is_cmd zgenom; then
  zgenom load mafredri/zsh-async
  zgenom load Tarrasch/zsh-bd
  zgenom load zsh-users/zsh-completions
  zgenom load zsh-users/zsh-autosuggestions . develop
  zgenom load romkatv/powerlevel10k powerlevel10k
  zgenom load zsh-users/zsh-history-substring-search
  zgenom load zsh-users/zsh-syntax-highlighting
  zgenom load ryutok/rust-zsh-completions
  zgenom load wfxr/forgit
fi
