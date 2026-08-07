# zarg — declarative argument parsing for zsh scripts.
#
# Declare the interface once; parsing, error messages, --help, --version and
# completions for zsh/fish/bash all derive from that declaration.
#
# This file only puts the library on fpath. Everything lives one function per
# file in functions/, so a consumer whose fpath is already set — which is the
# normal case, since the shell exports FPATH — skips this entirely and just
# says `autoload -Uz zarg`. See README.md.

fpath=(${0:A:h}/functions $fpath)
autoload -Uz ${0:A:h}/functions/*(N:t)
