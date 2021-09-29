#!zsh
is_cmd() {
  command -v $1 &>/dev/null
}

if ! is_cmd brew; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ !-d ~/.zgenon ]; then
  git clone https://github.com/jandamm/zgenom.git ~/.zgenom
fi

brew install \
  antibody \
  aria2 \
  asdf \
  bash \
  broot \
  cmatrix \
  fd \
  ffmpeg \
  fzf \
  git \
  gnupg \
  jq \
  lsd \
  nmap \
  pinentry \
  pinentry-macx \
  rar \
  ripgrep \
  starship \
  telnet \
  tig \
  tmux \
  youtube-dl \
  zoxide \
  zoxide

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

cargo install \
  fcp

brew tap AdoptOpenJDK/openjdk

brew install --cask \
  adoptopenjdk \
  android-sdk
