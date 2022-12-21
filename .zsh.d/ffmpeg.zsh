ff2mp4() {
  ffmpeg -find_stream_info -i $1 \
    -map 0 -c:v copy -c:a copy -c:s mov_text {1:r}.mp4 \
    -hide_banner -loglevel warning
}
ff2flac() {
  ffmpeg -find_stream_info -i $1 \
    -map 0 {1:r}.flac \
    -af aformat=s16:44100 \
    -hide_banner -loglevel warning
}

ffprobesubs() {
  ffprobe -v error -of json $1 -of json -show_entries stream -select_streams s
}
