# zarg — declarative argument parsing for zsh scripts.
#
# Declare the interface once; parsing, error messages, --help, --version and
# completions for zsh/fish/bash all derive from that declaration.
#
# This file only puts the library on fpath. Everything lives one function per
# file in functions/, so a consumer that has fpath set some other way can skip
# this entirely and just `autoload -Uz zarg_init zarg_flag zarg_opt zarg_arg
# zarg_go`. See README.md.

fpath=(${0:A:h}/functions $fpath)
autoload -Uz ${0:A:h}/functions/*(N:t)
