if is_cmd beet; then
  imp() {
    dst=~/inbox/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    rm -r $dst
    mkdir -p $dst
    echo "downloading..."
    curl $1 -o $dst/dl.zip
    echo "unzipping $dst/dl.zip"
    unzip -d $dst $dst/dl.zip
    echo "removing $dst/dl.zip"
    rm $dst/dl.zip
    echo "importing $dst..."
    beet import $dst -I
  }
fi
