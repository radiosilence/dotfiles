#!zsh
is_cmd() {
  command -v $1 &>/dev/null
}

if ! is_cmd brew; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ ! -d ~/.zgenom ]; then
  git clone https://github.com/jandamm/zgenom.git ~/.zgenom
fi

brew install \
  asdf \
  broot \
  fcp \
  fd \
  ffmpeg \
  fzf \
  git \
  gnupg \
  jq \
  lsd \
  nmap \
  pinentry \
  rar \
  ripgrep \
  starship \
  telnet \
  tig \
  tmux \
  youtube-dl \
  zoxide \
  zoxide

if ! is_cmd cargo; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi

cargo install \
  fcp

brew tap AdoptOpenJDK/openjdk

brew install --cask \
  adoptopenjdk \
  android-sdk
