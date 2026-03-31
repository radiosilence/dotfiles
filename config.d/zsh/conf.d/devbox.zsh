# Devbox — isolated dev containers
command -v docker &>/dev/null || return

dev() {
  local project="" ports="" repo=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      -p|--port) ports="$ports -p $2:$2"; shift 2 ;;
      -r|--repo) repo="$2"; shift 2 ;;
      -h|--help)
        printf 'usage: dev <project> [-p port] [-r repo]\n'
        printf '  dev b2c-spa                    start/attach\n'
        printf '  dev b2c-spa -p 3000            with port forward\n'
        printf '  dev b2c-spa -p 3000 -p 5432    multiple ports\n'
        printf '  dev b2c-spa -r git@gh:o/r.git  auto-clone on first run\n'
        return 0 ;;
      *) project="$1"; shift ;;
    esac
  done
  [[ -z "$project" ]] && { printf 'usage: dev <project> [-p port] [-r repo]\n'; return 1; }
  PORTS="$ports" REPO="$repo" task dev:start -- "$project"
}

dev-stop()   { task dev:stop -- "$@" }
dev-nuke()   { task dev:nuke -- "$@" }
dev-update() { task dev:update }
dev-ls()     { task dev:list }
dev-build()  { task dev:build }
dev-exec()   { local p=$1; shift; PROJECT="$p" task dev:exec -- "$@" }
