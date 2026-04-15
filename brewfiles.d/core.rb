# Core — essential system tools, always installed
tap 'buo/cask-upgrade'

brew 'zsh'
brew 'git'
cask '1password', greedy: true
cask '1password-cli', greedy: true

cask 'ghostty', greedy: true


brew 'curl'
brew 'coreutils'
brew 'findutils'
brew 'uv'
brew 'gnupg'
brew 'openssl@3'
brew 'mise'
brew 'gh'
brew 'pam-reattach'
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
