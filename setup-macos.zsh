#!/usr/bin/env zsh

echo "basename: [$(basename "$0")]"
echo "dirname : [$(dirname "$0")]"
echo "pwd     : [$(pwd)]"

export PATH="$(dirname "$0")/bin:$PATH"

. $(dirname $0)/common.zsh

if ! is_cmd brew; then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew bundle
$(dirname "$0")/install
. $HOME/.zshrc
mise install -y
install-font https://github.com/gaplo917/Ligatured-Hack/releases/download/v3.003%2BNv2.1.0%2BFC%2BJBMv2.242/HackLigatured-v3.003+FC3.1+JBMv2.242.zip
rustup default stable
