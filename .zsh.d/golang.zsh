if [ -d /usr/local/go ]; then
  export GOPATH=~/go
  export PATH="$GOPATH/bin:/usr/local/go/bin:$PATH"
fi
