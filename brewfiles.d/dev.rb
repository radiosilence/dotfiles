# Dev tools — editors, IDEs, clients
tap 'withgraphite/tap'
tap 'metalbear-co/mirrord'
tap 'tursodatabase/tap'

cask 'zed', greedy: true
cask 'fork', greedy: true
cask 'lens', greedy: true

# Databases
brew 'postgresql'
brew 'postgis'
brew 'libpq'
brew 'tursodatabase/tap/turso'
