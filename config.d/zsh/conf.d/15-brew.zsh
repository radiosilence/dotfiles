# The Homebrew prefix, where mise's brew manager links the formulae it
# installs, with or without Homebrew. Nothing here applies on Linux.
if [[ -d /opt/homebrew ]]; then
  export BREW_PREFIX=/opt/homebrew
elif [[ -x /usr/local/bin/brew ]]; then
  export BREW_PREFIX=/usr/local
else
  return
fi

path=("$BREW_PREFIX/bin" "$BREW_PREFIX/sbin" $path)
export PATH
