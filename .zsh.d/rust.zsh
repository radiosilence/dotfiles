export WASMTIME_HOME="$HOME/.wasmtime"
if [ -d "$WASMTIME_HOME" ]; then
  export PATH="$WASMTIME_HOME/bin:$PATH"
fi

export PATH="~/.cargo/bin:$PATH"
