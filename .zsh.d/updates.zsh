update_dotfiles() {
  if [ -d $DOTFILES_DIR ]; then
    (cd $DOTFILES_DIR && git pull)
  fi
}

updates() {
  update_dotfiles
  update_plugins

  if is_cmd asdf; then
    asdf plugin update --all
  fi

  if is_cmd youtube-dlc && is_cmd pip3; then
    pip3 install --upgrade youtube-dlc
  fi

  if is_macos; then
    brew update
    brew upgrade
    brew upgrade --cask
    brew cleanup
    brew doctor
  fi
}
