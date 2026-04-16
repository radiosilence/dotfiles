# Core — packages that must stay in brew (system integration, libs for mise runtimes).
# CLI tools have moved to Nix (see nix/packages.nix).
tap 'buo/cask-upgrade'

brew 'zsh'        # system shell registration
brew 'mise'       # project-level runtimes
brew 'pam-reattach'

cask '1password', greedy: true
cask '1password-cli', greedy: true
cask 'ghostty', greedy: true

brew 'uv'
brew 'openssl@3'
brew 'llvm'

# Build tools (some native extensions need these via brew paths)
brew 'cmake'
brew 'make'

# Libs needed by mise-managed runtimes that expect brew linker paths
brew 'gmp'
brew 'libyaml'
brew 'ossp-uuid'
brew 'readline'
brew 'xz'
