if is_macos; then
  ANTIDOTE_PATH="/opt/homebrew/opt/antidote/share/antidote"
else
  ANTIDOTE_PATH="$HOME/.antidote"
fi

if [ -d "$ANTIDOTE_PATH" ]; then
  source $ANTIDOTE_PATH/antidote.zsh
fi

if is_cmd antidote; then
  antidote load ${ZDOTDIR:-$HOME}/.zsh_plugins.txt
  # if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
  # zsh_plugins=${ZDOTDIR:-$HOME}/.zsh_plugins
  #   (
  #     source $ANTIDOTE_PATH/antidote.zsh
  #     antidote bundle <${zsh_plugins}.txt >${zsh_plugins}.zsh
  #   )
  # fi
  # source ${zsh_plugins}.zsh
fi
