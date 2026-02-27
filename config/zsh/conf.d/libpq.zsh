# PostgreSQL libpq configuration
[[ -d /opt/homebrew/opt/libpq ]] || return

export LDFLAGS="${LDFLAGS} -L/opt/homebrew/opt/libpq/lib"
export CPPFLAGS="${CPPFLAGS} -I/opt/homebrew/opt/libpq/include"
path=(/opt/homebrew/opt/libpq/bin $path)
export PATH
