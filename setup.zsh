#!zsh
brew install \
  \
  aria2 \
  antibody \
  bash \
  broot \
  cmatrix \
  zoxide \
  ffmpeg \
  fd \
  fzf \
  git \
  gnupg \
  jq \
  lsd \
  nmap \
  telnet \
  tig \
  tmux \
  tree \
  rar \
  ripgrep \
  pinentry \
  youtube-dl \
  watchman

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

cargo install \
  fcp

brew tap AdoptOpenJDK/openjdk

brew install --cask \
  adoptopenjdk \
  mpv \
  android-sdk
