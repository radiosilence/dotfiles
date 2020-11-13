imp() {
  dst=~/inbox/$1
  mkdir -p $dst/$1
  curl $2 -o $dst/dl.zip
  unzip ~/$dst/dl.zip
  rm $dst/dl.zip
  beet import $dst
}
