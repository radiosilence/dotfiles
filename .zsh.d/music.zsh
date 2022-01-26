flac2alac() {
  for i in *.flac; do
    echo $i → "${i%.flac}".m4a
    ffmpeg -i "$i" -y -v 0 -vcodec copy -acodec alac "${i%.flac}".m4a && rm -f "$i"
  done
}

importmusic() {
  (cd $1 && flac2alac)
  ssh music@soul "rm -rf ~/inbox/*"
  rsync -av $1 music@soul:inbox/
  ssh music@soul "beet import ~/inbox/*"
  (cd /Volumes/Stanley && ./pull.sh)
}
