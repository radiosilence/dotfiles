flac2alac() {
  for i in *.flac; do
    echo $i
    ffmpeg -i "$i" -y -v 0 -vcodec copy -acodec alac "${i%.flac}".m4a && rm -f "$i"
  done
}
