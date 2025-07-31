# PostgreSQL libpq configuration
export LDFLAGS="-L/opt/homebrew/opt/libpq/lib"
export CPPFLAGS="-I/opt/homebrew/opt/libpq/include"
path=(/opt/homebrew/opt/libpq/bin $path)
export PATH
