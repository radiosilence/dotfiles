#!/usr/bin/env zsh
# Output and process helpers for the scripts alongside this directory.
# Sourced, not run:
#
#   source "${0:A:h}/lib/common.zsh"
#
# Argument parsing, help and completions are zarg's job, not this file's.
# Everything here has three or more callers; anything with fewer belongs
# inline in the script that wants it.

# Colour only when stdout is a terminal, so piped output stays greppable.
if [[ -t 1 ]]; then
  _dt_mag=$'\e[35m'  _dt_cyan=$'\e[36m'   _dt_green=$'\e[32m'
  _dt_yellow=$'\e[33m' _dt_red=$'\e[31m'  _dt_grey=$'\e[90m'
  _dt_bold=$'\e[1m'  _dt_off=$'\e[0m'
else
  _dt_mag= _dt_cyan= _dt_green= _dt_yellow= _dt_red= _dt_grey= _dt_bold= _dt_off=
fi

_dt_head() { print -r -- ""; print -r -- "  ${_dt_mag}${_dt_bold}⟢${_dt_off} ${_dt_bold}$1${_dt_off}"; print -r -- "" }
_dt_info() { print -r -- "  ${_dt_cyan}→${_dt_off} $*" }
_dt_step() { print -r -- "  ${_dt_grey}·${_dt_off} $*" }
_dt_ok()   { print -r -- "  ${_dt_green}󰄬${_dt_off} $*" }
_dt_warn() { print -r -- "  ${_dt_yellow}󰀪${_dt_off} $*" }
_dt_err()  { print -ru2 -- "  ${_dt_red}󰅖${_dt_off} $*" }

# Ask before destructive work. $DT_YES (set by every -y flag) skips the ask;
# no tty answers "no", so a script piped into something never guesses yes.
_dt_confirm() {
  (( ${DT_YES:-0} )) && return 0
  [[ -t 0 ]] || return 1
  local reply
  read -q "reply?  $1 [y/N] "
  print -r -- ""
  [[ $reply == y ]]
}

# Fail once naming every missing dependency, rather than one round-trip each.
_dt_need() {
  local cmd; local -a missing
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  (( $#missing )) || return 0
  _dt_err "not installed: ${(j:, :)missing}"
  return 1
}

# Fan a snippet (its item arrives as "$1") over NUL-delimited stdin. GNU
# parallel when it's installed, xargs -P otherwise. Both pass the item as a
# real argument instead of substituting it textually, so paths survive intact;
# NUL because every caller here fans over filenames.
_dt_fan() {
  if command -v parallel >/dev/null 2>&1; then
    parallel -0 --will-cite -q sh -c "$1" _ {}
  else
    xargs -0 -P 8 -I {} sh -c "$1" _ {}
  fi
}

# NUL-delimited paths under ROOTS matching any extension, case-insensitively.
# Usage: _dt_files "wav aiff m4a" path...
_dt_files() {
  local -a exts=(${=1}); shift
  local -a expr; local e
  for e in $exts; do expr+=(-iname "*.$e" -o); done
  expr[-1]=()
  find "$@" -type f \( $expr \) -print0 2>/dev/null
}

_dt_cores() {
  if [[ $OSTYPE == darwin* ]]; then sysctl -n hw.ncpu 2>/dev/null || print 1
  else nproc 2>/dev/null || print 1
  fi
}

# Tally line for fanned-out work. The caller counts failures because only it
# knows what failure means.
_dt_results() {
  local ok=$1 failed=$2 verb=$3
  if (( failed )); then
    _dt_warn "$verb $ok files ($failed failed)"
  else
    _dt_ok "$verb $ok files"
  fi
}
