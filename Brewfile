# frozen_string_literal: true

# =============================================================================
# TAPS - Third-party repositories
# =============================================================================

tap 'buo/cask-upgrade'
tap 'nanovms/ops'
tap 'withgraphite/tap'
tap 'metalbear-co/mirrord'
tap 'hashicorp/tap'
tap 'tursodatabase/tap'

# =============================================================================
# CORE - Essential system tools and shell environment
# =============================================================================

brew 'zsh'
brew 'git'
brew 'git-lfs'
brew 'curl'
brew 'wget'
brew 'coreutils'
brew 'findutils'
brew 'gnupg'
brew 'openssl@3'
brew 'tmux'
brew 'tpm'

# =============================================================================
# DEV TOOLS - Editors, IDEs, and dev applications
# =============================================================================

cask 'zed', greedy: true
cask 'figma', greedy: true
cask 'fork', greedy: true
cask 'beekeeper-studio', greedy: true
cask 'lens', greedy: true

# =============================================================================
# BROWSERS
# =============================================================================

cask 'firefox', greedy: true
cask 'zen', greedy: true

# =============================================================================
# LANGUAGES - Runtimes and language tools
# =============================================================================

brew 'node'
brew 'mise'
brew 'uv'
brew 'luarocks'

# =============================================================================
# BUILD TOOLS - Compilers and build systems
# =============================================================================

brew 'cmake'
brew 'make'
brew 'llvm'
brew 'clang-format'

# =============================================================================
# LSPS - Language servers for editor integration
# =============================================================================

brew 'ansible-language-server'
brew 'elixir-ls'
brew 'lua-language-server'
brew 'rust-analyzer'
brew 'ruby-lsp'
brew 'solargraph'
brew 'terraform-ls'
brew 'vscode-langservers-extracted'
brew 'yaml-language-server'

# =============================================================================
# INFRA - Cloud, orchestration, and DevOps
# =============================================================================

brew 'ansible'
brew 'ansible-lint'
brew 'argocd'
brew 'awscli'
brew 'aws-shell'
brew 'aws-sso-util'
brew 'aws-vault'
brew 'azure-cli'
brew 'cf-terraforming'
brew 'hashicorp/tap/terraform'
brew 'pulumi'
brew 'tilt'
brew 'watchman'

# =============================================================================
# NETWORKING - Network tools and debugging
# =============================================================================

brew 'nmap'
brew 'iperf3'
brew 'telnet'
brew 'unbound'
brew 'grpcurl'

# =============================================================================
# CLI UTILS - Shell productivity and file management
# =============================================================================

brew 'bat'
brew 'fastfetch'
brew 'fcp'
brew 'htop'
brew 'btop'
brew 'hyperfine'
brew 'mas'
brew 'ripgrep'
brew 'shfmt'
brew 'tree'
brew 'tig'
brew 'helix'
brew 'golangci-lint'
brew 'swiftformat'
brew 'mdless'
brew 'exiftool'

# =============================================================================
# SYNC - File sync and transfer tools
# =============================================================================

brew 'fswatch'
brew 'parallel'
brew 'rsync'
brew 'rclone'
brew 'syncthing'

# =============================================================================
# MEDIA - Audio/video processing and playback
# =============================================================================

brew 'ffmpeg'
brew 'flac'
brew 'sox'
brew 'libsndfile'
brew 'atomicparsley'
brew 'cmus'
brew 'ttfautohint'

cask 'foobar2000', greedy: true
cask 'stolendata-mpv', args: { no_quarantine: true }, greedy: true
cask 'xld', args: { no_quarantine: true }, greedy: true

# =============================================================================
# DATABASE - Database clients and tools
# =============================================================================

brew 'postgresql'
brew 'libpq'
brew 'tursodatabase/tap/turso'

# =============================================================================
# LIBS - System libraries and dependencies
# =============================================================================

brew 'gmp'
brew 'libyaml'
brew 'ossp-uuid'
brew 'readline'
brew 'xz'

# =============================================================================
# API TOOLS - API testing and protocol buffers
# =============================================================================

# brew 'bufbuild/buf/buf'
brew 'evans'
brew 'jsonnet'
brew 'taplo'

# =============================================================================
# MISC - Specialized and experimental tools
# =============================================================================

brew 'aria2'
brew 'cmatrix'
brew 'ios-deploy'
brew 'metalbear-co/mirrord/mirrord'
brew 'nanovms/ops/ops'
brew 'qemu'
brew 'testdisk'
brew 'vercel-cli'
brew 'whalebrew'
brew 'withgraphite/tap/graphite'
brew 'wrk'

# =============================================================================
# PRODUCTIVITY - Office and productivity apps
# =============================================================================

cask 'notion', greedy: true
cask 'notion-calendar', greedy: true
cask '1password', greedy: true
cask '1password-cli', greedy: true
cask 'claude', greedy: true

# =============================================================================
# COMMUNICATION - Messaging and collaboration
# =============================================================================

cask 'discord', greedy: true
cask 'signal', greedy: true

# =============================================================================
# SYSTEM - Terminal emulators and system utilities
# =============================================================================

cask 'ghostty', greedy: true
cask 'orbstack', greedy: true
cask 'rar', args: { no_quarantine: true }, greedy: true
cask 'tailscale', greedy: true
cask 'aws-vpn-client', greedy: true
cask 'mullvad-vpn', greedy: true
cask 'steam'

# =============================================================================
# CREATIVE - Adobe and audio production
# =============================================================================

cask 'adobe-creative-cloud', greedy: true
cask 'focusrite-control', greedy: true

# =============================================================================
# DEV CLIENTS - API and GraphQL clients
# =============================================================================

cask 'altair-graphql-client', greedy: true

# =============================================================================
# MAC APP STORE
# =============================================================================

cask_args require_sha: true

# Replaced mas with casks (mas is buggy)
cask '1password'
cask 'slack'
cask 'telegram'
cask 'whatsapp'

# No cask alternatives available
mas 'Adobe Lightroom', id: 1_451_544_217
mas 'Infuse', id: 1_136_220_934
