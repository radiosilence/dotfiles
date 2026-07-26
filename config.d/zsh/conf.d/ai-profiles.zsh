# Shared profile resolver for the AI coding CLIs (claude, omp).
#
# `_ai_profile <config.yaml>` reads a profiles file and picks one from $PWD:
#   profiles:
#     - profile: ~/.claude              # config dir for this profile
#       roots: [~/workspace/acme]       # cwd under any root => this profile
#       args: [--remote-control]        # extra flags to launch with (optional)
#     - profile: ~/.claude-personal
#       default: true                   # used when no root matches
#
# The profile whose *longest* matching root is a prefix of $PWD wins; with no match
# it falls back to `default: true`. Missing config / yq / match / default -> prints an
# empty line and callers use the tool's own default.
#
# Prints a single TAB-separated line: "<abs-config-dir>\t<space-joined args>".
_ai_profile() {
  local cfg=${1/#\~/$HOME}
  { [[ -r $cfg ]] && (( $+commands[yq] )); } || { print -r --; return; }

  local pwd_abs=${PWD:A} best= bestlen=-1 bestargs= root dir args
  while IFS=$'\t' read -r root dir args; do
    root=${root/#\~/$HOME}
    if [[ $pwd_abs == $root || $pwd_abs == $root/* ]] && (( $#root > bestlen )); then
      best=$dir bestlen=$#root bestargs=$args
    fi
  done < <(yq -r '.profiles[] | select(.roots) | .profile as $p | (.args // [] | join(" ")) as $a | .roots[] | . + "\t" + $p + "\t" + $a' "$cfg" 2>/dev/null)

  if [[ -z $best ]]; then
    IFS=$'\t' read -r best bestargs < <(yq -r '.profiles[] | select(.default == true) | .profile + "\t" + (.args // [] | join(" "))' "$cfg" 2>/dev/null)
  fi

  [[ -n $best ]] && best=${best/#\~/$HOME}
  print -r -- "${best}"$'\t'"${bestargs}"
}
