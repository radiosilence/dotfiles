is_cmd() {
  command -v $1 &>/dev/null
}

is_macos() {
  [ -d /Library ]
}

join_by() {
  local d=$1
  shift
  local f=$1
  shift
  printf %s "$f" "${@/#/$d}"
}

bold=$(tput bold)
normal=$(tput sgr0)
