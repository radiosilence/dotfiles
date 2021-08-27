if is_cmd yt-dlp; then
  alias ytdl='yt-dlp'
elif is_cmd youtube-dlc; then
  alias ytdl='youtube-dlc'
elif is_cmd youtube-dl; then
  alias ytdl='youtube-dl'
fi
