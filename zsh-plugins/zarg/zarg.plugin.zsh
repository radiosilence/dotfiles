# zarg — declarative argument parsing for zsh scripts.
#
# Declare the interface once; parsing, error messages, --help, --version and
# completions for zsh/fish/bash all derive from that declaration. The
# completions are the reason this exists: a hand-written compdef drifts from
# the parser the moment you add a flag, and every script here needs both.
#
# Sourced by sheldon for interactive use, and directly by scripts:
#   source "${0:A:h:h}/zsh-plugins/zarg/zarg.plugin.zsh"
#
# See README.md for the spec API.

(( ${+functions[zarg_init]} )) && return 0

typeset -g ZARG_HOME=${0:A:h}

# Records are \x1f-delimited because help text may contain anything else.
typeset -g  ZARG_SEP=$'\x1f'
typeset -g  ZARG_NAME ZARG_DESC
typeset -ga ZARG_FLAGS ZARG_OPTS ZARG_ARGS

# Field <index> of a \x1f record.
_zarg_f() { local -a p=("${(@ps:$ZARG_SEP:)1}"); print -r -- "${p[$2]}" }

# --dry-run / paths -> dry_run / paths
_zarg_dest() { local s=${1#--}; print -r -- "${s//-/_}" }

# Pull key=value extras off the end of a declaration into _zarg_x.
_zarg_extras() {
  local kv
  _zarg_x=()
  for kv in "$@"; do
    if [[ $kv == *=* ]]; then _zarg_x[${kv%%=*}]=${kv#*=}
    else                      _zarg_x[$kv]=1
    fi
  done
}

zarg_init() {
  ZARG_NAME=$1 ZARG_DESC=$2
  ZARG_FLAGS=() ZARG_OPTS=() ZARG_ARGS=()
}

# zarg_flag -n --dry-run 'help'
zarg_flag() {
  ZARG_FLAGS+=("${1}${ZARG_SEP}${2}${ZARG_SEP}${3}${ZARG_SEP}$(_zarg_dest $2)")
}

# zarg_opt -s --signal 'help' [default=X] [env=VAR] [values='a b'] [complete=_fn] [metavar=SIG]
zarg_opt() {
  local short=$1 long=$2 help=$3; shift 3
  local -A _zarg_x; _zarg_extras "$@"
  local dest=$(_zarg_dest $long)
  ZARG_OPTS+=("${short}${ZARG_SEP}${long}${ZARG_SEP}${help}${ZARG_SEP}${dest}${ZARG_SEP}${_zarg_x[default]}${ZARG_SEP}${_zarg_x[env]}${ZARG_SEP}${_zarg_x[values]}${ZARG_SEP}${_zarg_x[complete]}${ZARG_SEP}${_zarg_x[metavar]:-${dest:u}}")
}

# zarg_arg paths 'help' [required] [variadic] [default=X] [values='a b'] [complete=_fn]
zarg_arg() {
  local name=$1 help=$2; shift 2
  local -A _zarg_x; _zarg_extras "$@"
  ZARG_ARGS+=("${name}${ZARG_SEP}${help}${ZARG_SEP}${_zarg_x[required]:-0}${ZARG_SEP}${_zarg_x[variadic]:-0}${ZARG_SEP}${_zarg_x[default]}${ZARG_SEP}${_zarg_x[values]}${ZARG_SEP}${_zarg_x[complete]}")
}

# ── Errors ───────────────────────────────────────────────────────────

# Every option the user could have meant, for the did-you-mean hint.
_zarg_known() {
  local rec
  for rec in "$ZARG_FLAGS[@]" "$ZARG_OPTS[@]"; do
    print -r -- "$(_zarg_f "$rec" 1)"; print -r -- "$(_zarg_f "$rec" 2)"
  done
  print -r -- "--help"; print -r -- "--version"; print -r -- "--completions"
}

# A wrong flag is nearly always a typo or a half-remembered name, so lead with
# the closest match rather than making them read the whole help.
_zarg_suggest() {
  local bad=${1#-} cand
  for cand in $(_zarg_known); do
    [[ ${#bad} -ge 2 && ${cand#-} == ${bad}* ]] && { print -r -- "$cand"; return 0 }
  done
  for cand in $(_zarg_known); do
    [[ ${#bad} -ge 3 && ${cand#-} == *${bad[1,3]}* ]] && { print -r -- "$cand"; return 0 }
  done
  return 1
}

_zarg_die() {
  print -ru2 -- "$ZARG_NAME: $1"
  local hint
  [[ -n $2 ]] && hint=$(_zarg_suggest "$2") && print -ru2 -- "  did you mean '$hint'?"
  print -ru2 -- "  try '$ZARG_NAME --help'"
}

# ── Parsing ──────────────────────────────────────────────────────────

_zarg_lookup() {
  local tok=$1 rec
  for rec in "${(@P)2}"; do
    [[ $tok == $(_zarg_f "$rec" 1) || $tok == $(_zarg_f "$rec" 2) ]] && { print -r -- "$rec"; return 0 }
  done
  return 1
}

zarg_parse() {
  local rec dest tok val envvar
  local -a rest

  # Defaults, then environment, then the command line — each overriding the
  # last, which is the order a user expects.
  for rec in "$ZARG_FLAGS[@]"; do typeset -g "$(_zarg_f "$rec" 4)"=0; done
  for rec in "$ZARG_OPTS[@]"; do
    dest=$(_zarg_f "$rec" 4)
    typeset -g "$dest"="$(_zarg_f "$rec" 5)"
    envvar=$(_zarg_f "$rec" 6)
    [[ -n $envvar && -n ${(P)envvar} ]] && typeset -g "$dest"="${(P)envvar}"
  done

  while (( $# )); do
    case $1 in
      --) shift; rest+=("$@"); break ;;

      --*=*)
        tok=${1%%=*} val=${1#*=}
        if rec=$(_zarg_lookup "$tok" ZARG_OPTS); then
          typeset -g "$(_zarg_f "$rec" 4)"="$val"
        elif _zarg_lookup "$tok" ZARG_FLAGS >/dev/null; then
          _zarg_die "$tok is a flag and takes no value"; return 2
        else
          _zarg_die "unknown option: $tok" "$tok"; return 2
        fi
        shift ;;

      --*|-[a-zA-Z])
        if rec=$(_zarg_lookup "$1" ZARG_FLAGS); then
          typeset -g "$(_zarg_f "$rec" 4)"=1; shift
        elif rec=$(_zarg_lookup "$1" ZARG_OPTS); then
          (( $# >= 2 )) || { _zarg_die "$1 needs a value"; return 2 }
          typeset -g "$(_zarg_f "$rec" 4)"="$2"; shift 2
        else
          _zarg_die "unknown option: $1" "$1"; return 2
        fi ;;

      # Clustered shorts (-nk) and attached values (-b192).
      -[a-zA-Z][a-zA-Z0-9]*)
        local cluster=${1#-}
        shift
        while [[ -n $cluster ]]; do
          tok="-${cluster[1]}" cluster=${cluster[2,-1]}
          if rec=$(_zarg_lookup "$tok" ZARG_FLAGS); then
            typeset -g "$(_zarg_f "$rec" 4)"=1
          elif rec=$(_zarg_lookup "$tok" ZARG_OPTS); then
            if [[ -n $cluster ]]; then
              typeset -g "$(_zarg_f "$rec" 4)"="$cluster"; cluster=
            else
              (( $# >= 1 )) || { _zarg_die "$tok needs a value"; return 2 }
              typeset -g "$(_zarg_f "$rec" 4)"="$1"; shift
            fi
          else
            _zarg_die "unknown option: $tok" "$tok"; return 2
          fi
        done ;;

      *) rest+=("$1"); shift ;;
    esac
  done

  # Reject values outside a declared set here rather than in every script.
  local values
  for rec in "$ZARG_OPTS[@]"; do
    values=$(_zarg_f "$rec" 7); dest=$(_zarg_f "$rec" 4)
    [[ -n $values && -n ${(P)dest} ]] || continue
    (( ${${=values}[(I)${(P)dest}]} )) || {
      _zarg_die "$(_zarg_f "$rec" 2): '${(P)dest}' is not one of: ${values}"; return 2 }
  done

  # Positionals. A variadic one swallows what is left, so it must be declared last.
  local i=1 name variadic required default
  for rec in "$ZARG_ARGS[@]"; do
    name=$(_zarg_f "$rec" 1) required=$(_zarg_f "$rec" 3)
    variadic=$(_zarg_f "$rec" 4) default=$(_zarg_f "$rec" 5) values=$(_zarg_f "$rec" 6)
    if (( variadic )); then
      local -a taken=("${rest[@]:$((i-1))}")
      (( $#taken )) || taken=(${=default})
      (( $#taken )) || (( ! required )) || { _zarg_die "missing argument: $name"; return 2 }
      typeset -ga "$name"; set -A "$name" "${taken[@]}"
      i=$(( i + $#taken ))
    else
      val=${rest[$i]:-$default}
      if [[ -z $val ]] && (( required )); then _zarg_die "missing argument: $name"; return 2; fi
      if [[ -n $values && -n $val ]] && (( ! ${${=values}[(I)$val]} )); then
        _zarg_die "$name: '$val' is not one of: ${values}"; return 2
      fi
      typeset -g "$name"="$val"
      (( i++ ))
    fi
  done

  (( i > $#rest )) || { _zarg_die "unexpected argument: ${rest[$i]}"; return 2 }
  return 0
}

# ── Help and version ─────────────────────────────────────────────────

zarg_help() {
  local rec name
  local -a usage=("$ZARG_NAME")
  (( $#ZARG_FLAGS || $#ZARG_OPTS )) && usage+=("[options]")
  for rec in "$ZARG_ARGS[@]"; do
    name=$(_zarg_f "$rec" 1)
    if (( $(_zarg_f "$rec" 3) )); then usage+=("<$name>"); else usage+=("[$name]"); fi
    (( $(_zarg_f "$rec" 4) )) && usage[-1]="${usage[-1]}..."
  done

  print -r -- ""
  print -r -- "  $ZARG_DESC"
  print -r -- ""
  print -r -- "  usage: ${usage[*]}"

  if (( $#ZARG_ARGS )); then
    print -r -- ""
    print -r -- "  arguments:"
    for rec in "$ZARG_ARGS[@]"; do
      printf '    %-24s %s\n' "$(_zarg_f "$rec" 1)" "$(_zarg_f "$rec" 2)"
    done
  fi

  print -r -- ""
  print -r -- "  options:"
  for rec in "$ZARG_FLAGS[@]"; do
    printf '    %-24s %s\n' "$(_zarg_f "$rec" 1), $(_zarg_f "$rec" 2)" "$(_zarg_f "$rec" 3)"
  done
  local def envvar note
  for rec in "$ZARG_OPTS[@]"; do
    def=$(_zarg_f "$rec" 5); envvar=$(_zarg_f "$rec" 6); note=
    [[ -n $def ]]    && note=" (default: $def)"
    [[ -n $envvar ]] && note="$note (\$$envvar)"
    printf '    %-24s %s%s\n' \
      "$(_zarg_f "$rec" 1), $(_zarg_f "$rec" 2) $(_zarg_f "$rec" 9)" "$(_zarg_f "$rec" 3)" "$note"
  done
  printf '    %-24s %s\n' "-h, --help" "show this help"
  printf '    %-24s %s\n' "--version" "show version"
  printf '    %-24s %s\n' "--completions SHELL" "emit completions (zsh, fish, bash)"
  print -r -- ""
}

# These scripts ship with the dotfiles and are versioned by them, so the repo's
# own description is the only honest answer.
zarg_version() {
  local v=${ZARG_VERSION:-$(git -C "${ZARG_HOME:h:h}" describe --tags --always --dirty 2>/dev/null)}
  print -r -- "$ZARG_NAME ${v:-unknown} (dotfiles)"
}

# ── Entry point ──────────────────────────────────────────────────────

# Handle the built-ins, then parse. Scripts call this instead of zarg_parse; it
# exits on its own for --help/--version/--completions and on a parse error, so
# a script may assume a good parse once it returns.
zarg_go() {
  local i
  for (( i = 1; i <= $#; i++ )); do
    case ${@[i]} in
      --) break ;;
      -h|--help) zarg_help; exit 0 ;;
      --version) zarg_version; exit 0 ;;
      --completions|--completions=*)
        local shell=${${@[i]}#--completions}
        shell=${shell#=}
        [[ -n $shell ]] || shell=${@[i+1]}
        source "$ZARG_HOME/completions.zsh"
        zarg_completions "${shell:-zsh}" || exit 1
        exit 0 ;;
    esac
  done
  zarg_parse "$@" || exit $?
}
