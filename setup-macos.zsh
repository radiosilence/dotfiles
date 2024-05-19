#!/bin/zsh
# list of programs to install:
# * Code
# * Firefox
# * Chrome
# * Kitty
# * Alacritty if dev is not a jerk
# * Telegram
# * Whatsapp
# * Signal
# * Slack
# * 1Password
# * Discord
# * Spotify
# * Teams
# * Twitch
# * Outlook
# * Office
# * SoundCleod
# * Cog
# * IINA
# * Creative Cloud
# * Paw
# * Figma

is_cmd() {
	command -v $1 &>/dev/null
}

install_font() {
	tmpdir=$(mktemp -d)
	mkdir -p $tmpdir
	aria2c $1 -d $tmpdir
	unzip $tmpdir/*.zip -d $tmpdir
	cp -v $tmpdir/*.{ttf,otf} ~/Library/Fonts
	rm -rf $tmpdir
}

if ! is_cmd brew; then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew install \
	bat \
	broot \
	clang-format \
	efm-langserver \
	fastlane \
	fcp \
	ffmpeg \
	fzf \
	gh \
	git \
	gnupg \
	helix \
	lsd \
	make \
	mise \
	nmap \
	pulumi \
	qemu \
	rsync \
	sheldon \
	taplo \
	telnet \
	tig \
	tmux \
	zoxide

brew install --cask \
	rar \
	wezterm \
	mpv

install_font https://github.com/gaplo917/Ligatured-Hack/releases/download/v3.003%2BNv2.1.0%2BFC%2BJBMv2.242/HackLigatured-v3.003+FC3.1+JBMv2.242.zip

rustup default stable

mise install -y

sudo softwareupdate --install-rosetta
