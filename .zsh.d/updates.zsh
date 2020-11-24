updates() {
  asdf plugin update --all
  update_plugins
  pip3 install --upgrade youtube-dlc
  brew update
  brew upgrade
  brew upgrade --cask
  brew cleanup
  brew doctor
}
