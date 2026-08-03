# Core — essential system tools, always installed

brew 'zsh'
cask 'ghostty'
brew 'git'
cask '1password'
cask '1password-cli'

# Fonts — auto-updated via brew upgrade
cask 'font-geist'
cask 'font-geist-mono'
cask 'font-geist-mono-nerd-font'
cask 'font-departure-mono'
cask 'font-departure-mono-nerd-font'

cask 'betterdisplay'

brew 'curl'
brew 'coreutils'
brew 'findutils'
brew 'gnupg'
brew 'openssl@3'
brew 'libressl' # shadows /usr/bin/openssl (LibreSSL 3.3.6, 2021) — see 16-shadows.zsh
brew 'mise'
brew 'gh'
brew 'node' # need a global npm for mise's npm: backend even when aube is the resolver
brew 'uv' # global uv/uvx for mise's pipx: backend (e.g. snowflake-cli); brew runs pre-mise so it's there at install time
brew 'pam-reattach' # Touch ID inside zellij/tmux-style detached sessions
brew 'sheldon' if Hardware::CPU.intel?

# Build tools
brew 'cmake'
brew 'make'
brew 'llvm'

# CLI utils
brew 'fcp'
brew 'htop'
brew 'btop'
brew 'mas'
brew 'tokei'
brew 'cmatrix'
brew 'unar'
brew 'testdisk'

# Sync
brew 'fswatch'
brew 'parallel'
brew 'rsync'
brew 'aria2'

# Libs
brew 'gmp'
brew 'libyaml'
brew 'ossp-uuid'
brew 'readline'
brew 'xz'
