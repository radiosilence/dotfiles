update_dotfiles() {
  if [ -d "$DOTFILES" ]; then
    echo "updating dotfiles $DOTFILES"
    (cd "$DOTFILES" && git pull)
  fi
}

updates() {
  update_dotfiles
  update_plugins

  if is_cmd asdf; then
    echo "updating asdf..."
    asdf plugin update --all
  fi

  if is_cmd youtube-dlc && is_cmd pip3; then
    echo "updating youtube-dlc"
    pip3 install --upgrade youtube-dlc
  fi

  if is_macos; then
    echo "updating brew"
    brew update
    brew upgrade
    brew upgrade --cask
    brew cleanup
    brew doctor
  fi
}
