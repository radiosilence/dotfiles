if [ -f ~/.asdf/asdf.sh ]; then
  . ~/.asdf/asdf.sh
elif [ -d $BREW_PREFIX/opt/asdf ]; then
  . $BREW_PREFIX/opt/asdf/libexec/asdf.sh
fi
# direnv
if is_cmd direnv; then
  source "${XDG_CONFIG_HOME:-$HOME/.config}/asdf-direnv/zshrc"
  export DIRENV_LOG_FORMAT=""
  PATH="~/.asdf/bin:$PATH"
fi
