h264() {
  ffmpeg -y -i $1 -c:v libx264 -b:v $3 -pass 1 -an -f null /dev/null &&
    ffmpeg -y -i $1 -c:v libx264 -b:v $3 -pass 2 -c:a aac -b:a 128k $2
}
