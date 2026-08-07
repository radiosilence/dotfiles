# zarg — declarative argument parsing for zsh scripts.
#
# Declare the interface once; parsing, error messages, --help, --version and
# completions for zsh/fish/bash all derive from that declaration. The
# completions are the reason this exists: a hand-written compdef drifts from
# the parser the moment you add a flag, and every script here needs both.
#
# This file is only a loader. The implementation lives one function per file in
# functions/, so sourcing zarg costs three lines rather than parsing the whole
# library — and a script that never asks for fish completions never loads the
# fish emitter. See README.md for the spec API.

(( ${+functions[zarg_init]} )) && return 0

typeset -g  ZARG_HOME=${0:A:h}
# Records are \x1f-delimited because help text may contain anything else.
typeset -g  ZARG_SEP=$'\x1f'
typeset -g  ZARG_NAME ZARG_DESC
typeset -ga ZARG_FLAGS ZARG_OPTS ZARG_ARGS

# Globbed rather than listed, so adding a function needs no edit here.
fpath=($ZARG_HOME/functions $fpath)
autoload -Uz $ZARG_HOME/functions/*(N:t)
