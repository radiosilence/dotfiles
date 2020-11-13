imp() {
  dst=~/inbox/_imp
  rm -r $dst
  mkdir -p $dst
  echo "downloading..."
  curl $1 -o $dst/dl.zip
  echo "unzipping $dst/dl.zip"
  unzip $dst/dl.zip
  echo "removing $dst/dl.zip"
  rm $dst/dl.zip
  echo "importing $dst..."
  beet import $dst
}
