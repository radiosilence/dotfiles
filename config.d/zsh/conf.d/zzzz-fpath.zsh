# A script runs in its own zsh and inherits no functions — but FPATH is a real
# environment variable tied to $fpath, exactly as PATH is to $path. Exporting
# it hands every child the same function libraries this shell just loaded, so
# a script can `autoload -Uz zarg_init` without knowing where anything lives.
#
# Named to sort last in conf.d: it has to run after everything that adds to
# fpath, which includes sheldon sourcing the plugins.
export FPATH
