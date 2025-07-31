# Editor configuration
if command -v hx >/dev/null; then
  export EDITOR=hx
elif command -v vim >/dev/null; then
  export EDITOR=vim
else
  export EDITOR=vi
fi
