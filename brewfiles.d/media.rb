# Media — audio/video processing and playback
brew 'ffmpeg'
brew 'flac'
brew 'sox'
brew 'libsndfile'
brew 'atomicparsley'

cask 'foobar2000', greedy: true
cask 'stolendata-mpv', args: { no_quarantine: true }, greedy: true
