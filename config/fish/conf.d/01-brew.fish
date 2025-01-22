if test -d /opt/homebrew
    set -gx BREW_PREFIX /opt/homebrew
else
    set -gx BREW_PREFIX /usr/local
end

fish_add_path "$BREW_PREFIX/bin"
fish_add_path "$BREW_PREFIX/sbin"

using brew || exit
set -gx HOMEBREW_BUNDLE_FILE "~/Brewfile"
alias bb "brew bundle"
