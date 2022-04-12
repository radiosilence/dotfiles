# asdf
if [ -f ~/.asdf/asdf.sh ]; then
  . ~/.asdf/asdf.sh
fi

if [ -d $BREW_PREFIX/opt/asdf ]; then
  . $BREW_PREFIX/opt/asdf/libexec/asdf.sh
fi

if is_cmd asdf; then
  # Hook direnv into your shell.
  eval "$(asdf exec direnv hook bash)"

  # A shortcut for asdf managed direnv.
  direnv() { asdf exec direnv "$@"; }
fi
