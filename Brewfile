# frozen_string_literal: true

# =============================================================================
# TAPS - Third-party repositories
# =============================================================================

tap 'buo/cask-upgrade'
tap 'nanovms/ops'
tap 'withgraphite/tap'
tap 'metalbear-co/mirrord'
tap 'hashicorp/tap'
tap 'supersonic-app/supersonic'
tap 'tursodatabase/tap'

# =============================================================================
# CORE - Essential system tools and shell environment
# =============================================================================

brew 'zsh'
brew 'git'

brew 'curl'
brew 'coreutils'
brew 'findutils'
brew 'gnupg'
brew 'openssl@3'
brew 'mise'
brew 'gh' # Fallback for mise private repo access
brew 'sheldon' # fallback for darwin-x64

# =============================================================================
# DEV TOOLS - Editors, IDEs, and dev applications
# =============================================================================

cask 'zed', greedy: true
cask 'zed@preview', greedy: true
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

brew 'luarocks'
brew 'uv' # Required for mise pipx backend

# =============================================================================
# BUILD TOOLS - Compilers and build systems
# =============================================================================

brew 'cmake'
brew 'make'
brew 'llvm'
brew 'clang-format'

# =============================================================================
# INFRA - Cloud, orchestration, and DevOps
# =============================================================================

brew 'awscli'
brew 'aws-shell'
brew 'aws-sso-util'

brew 'cf-terraforming'

brew 'watchman'

# =============================================================================
# NETWORKING - Network tools and debugging
# =============================================================================

brew 'aria2'
brew 'nmap'
brew 'iperf3'
brew 'telnet'
brew 'unbound'

# =============================================================================
# CLI UTILS - Shell productivity and file management
# =============================================================================

brew 'fcp'
brew 'htop'
brew 'btop'
brew 'mas'

brew 'mdless'
brew 'exiftool'

# =============================================================================
# SYNC - File sync and transfer tools
# =============================================================================

brew 'fswatch'
brew 'parallel'
brew 'rsync'

brew 'syncthing'

# =============================================================================
# MEDIA - Audio/video processing and playback
# =============================================================================

brew 'flac'
brew 'sox'
brew 'libsndfile'
brew 'atomicparsley'

cask 'foobar2000', greedy: true
cask 'stolendata-mpv', args: { no_quarantine: true }, greedy: true

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

brew 'jsonnet'

# =============================================================================
# MISC - Specialized and experimental tools
# =============================================================================

brew 'cmatrix'
brew 'ios-deploy'

brew 'nanovms/ops/ops'
brew 'qemu'
brew 'testdisk'

brew 'whalebrew'

brew 'oha'
brew 'tokei'

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
cask 'tailscale-app', greedy: true
cask 'aws-vpn-client', greedy: true
cask 'mullvad-vpn', greedy: true
cask 'steam', greedy: true

# =============================================================================
# CREATIVE - Adobe and audio production
# =============================================================================

cask 'adobe-creative-cloud', greedy: true
cask 'focusrite-control', greedy: true

# =============================================================================
# DEV CLIENTS - API and GraphQL clients
# =============================================================================

cask 'altair-graphql-client', greedy: true

cask_args require_sha: true

cask 'slack', greedy: true
cask 'telegram', greedy: true
cask 'whatsapp', greedy: true

# =============================================================================
# MAC APP STORE
# =============================================================================

mas 'Adobe Lightroom', id: 1_451_544_217
mas 'Infuse', id: 1_136_220_934
