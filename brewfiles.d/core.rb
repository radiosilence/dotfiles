# Core — essential system tools, always installed

brew 'zsh'
brew 'git'
cask '1password', greedy: true
cask '1password-cli', greedy: true

brew 'curl'
brew 'coreutils'
brew 'findutils'
brew 'gnupg'
brew 'openssl@3'
brew 'mise'
brew 'gh'
brew 'sheldon' if Hardware::CPU.intel?

# Build tools
brew 'cmake'
brew 'make'
brew 'llvm'
brew 'clang-format'

# Languages
brew 'luarocks'
brew 'uv'

# CLI utils
brew 'fcp'
brew 'htop'
brew 'btop'
brew 'mas'
brew 'mdless'
brew 'exiftool'
brew 'tokei'
brew 'oha'
brew 'cmatrix'
cask 'rar', args: { no_quarantine: true }, greedy: true

# Sync
brew 'fswatch'
brew 'parallel'
brew 'rsync'
brew 'syncthing'
brew 'aria2'

# Libs
brew 'gmp'
brew 'libyaml'
brew 'ossp-uuid'
brew 'readline'
brew 'xz'
