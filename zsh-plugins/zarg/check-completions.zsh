#!/usr/bin/env zsh
# zarg's integration test: prove every script using it still parses, renders
# help, and emits completions the target shells actually accept. test.zsh
# covers zarg against a fixture; this covers it against real consumers.
#
# Run bare to sweep scripts/ and every plugin bin/, or pass specific files.
set -o pipefail

# Point FPATH at THIS checkout, then export it so the scripts we invoke inherit
# it. An interactive shell would have done this already, but CI has no such
# shell — and a worktree must test its own libraries, not ~/.dotfiles'.
local root=${0:A:h:h:h}
fpath=($root/zsh-plugins/*/functions(N) $root/scripts/lib/functions(N) $fpath)
export FPATH

local -a targets
if (( $# )); then
  targets=("$@")
else
  # Executable regular files only: the README documents zarg and would other-
  # wise match the grep below, then get run. Plugin bin/ dirs are in scope too
  # — wtclean is a zarg script that just doesn't live on $PATH.
  targets=($root/scripts/*(N-.x) $root/zsh-plugins/*/bin/*(N-.x))
fi

local -i failures=0
local f name

_fail() { print -ru2 -- "  FAIL  $1"; (( failures++ )) }

for f in $targets; do
  [[ -f $f && -x $f ]] || continue
  grep -q '^zarg_go' "$f" 2>/dev/null || continue
  name=${f:t}

  zsh -n "$f"                 || _fail "$name: syntax"
  "$f" --help    >/dev/null   || _fail "$name: --help"
  "$f" --version >/dev/null   || _fail "$name: --version"

  "$f" --completions zsh  2>/dev/null | zsh  -n /dev/stdin 2>/dev/null || _fail "$name: zsh completion"
  "$f" --completions bash 2>/dev/null | bash -n /dev/stdin 2>/dev/null || _fail "$name: bash completion"
  if command -v fish >/dev/null 2>&1; then
    "$f" --completions fish 2>/dev/null | fish -n /dev/stdin 2>/dev/null || _fail "$name: fish completion"
  else
    "$f" --completions fish >/dev/null 2>&1 || _fail "$name: fish completion"
  fi

  # An unknown shell must be refused rather than silently emitting zsh.
  "$f" --completions tcsh >/dev/null 2>&1 && _fail "$name: accepted an unknown shell"
done

if (( failures )); then
  print -ru2 -- "$failures completion check(s) failed"
  exit 1
fi
print -r -- "completions OK"
