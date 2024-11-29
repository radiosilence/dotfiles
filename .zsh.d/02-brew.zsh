[ -d /opt/homebrew ] && export BREW_PREFIX=/opt/homebrew || export BREW_PREFIX=/usr/local
export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"

export HOMEBREW_BUNDLE_FILE="~/Brewfile"

brew-bundle-install() {
  echo 'brew "'$1'"' >>$HOME/Brewfile && brew bundle
}
