if test -d /opt/homebrew
  set -gx BREW_PREFIX /opt/homebrew
else
  set -gx BREW_PREFIX /usr/local
end

fish_add_path "$BREW_PREFIX/bin"

using brew || exit
set -gx HOMEBREW_BUNDLE_FILE "~/Brewfile"
alias bb "brew bundle"
