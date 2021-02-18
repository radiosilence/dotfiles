wanip4() {
  dig @resolver4.opendns.com myip.opendns.com +short -4
}

weather() {
  curl "https://wttr.in/$1"
}
