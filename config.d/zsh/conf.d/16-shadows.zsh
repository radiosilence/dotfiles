# Shadow macOS's frozen system tools with current Homebrew builds.
# These are all keg-only or g-prefixed, so brew deliberately leaves them off
# PATH — putting them on is a choice, made here in one place.
#
# Runs after 15-brew so these beat /opt/homebrew/bin, and before the
# alphabetical files so ~/.dotfiles/bin still wins.

# GNU Make 4.4.1 — Apple froze at 3.81 (2006, pre-GPLv3): no .ONESHELL, no !=,
# no $(file ...). Modern Makefiles simply don't run.
[[ -d /opt/homebrew/opt/make/libexec/gnubin ]] && path=(/opt/homebrew/opt/make/libexec/gnubin $path)

# GNU coreutils/findutils unprefixed — date -d, find -printf, stat -c, xargs -r,
# readlink -f. BSD equivalents differ enough that Linux one-liners are a coin flip.
[[ -d /opt/homebrew/opt/coreutils/libexec/gnubin ]] && path=(/opt/homebrew/opt/coreutils/libexec/gnubin $path)
[[ -d /opt/homebrew/opt/findutils/libexec/gnubin ]] && path=(/opt/homebrew/opt/findutils/libexec/gnubin $path)

# curl 8.21 — Apple's 8.7.1 links zlib only, so any response with
# Content-Encoding: br or zstd dies with "Unrecognized content encoding type".
# Also no HTTP/3, and still on LibreSSL/SecureTransport.
[[ -d /opt/homebrew/opt/curl/bin ]] && path=(/opt/homebrew/opt/curl/bin $path)

# LibreSSL 4.3.2 — /usr/bin/openssl is LibreSSL 3.3.6 (2021). Staying on
# LibreSSL rather than OpenSSL keeps the CLI semantics anything on macOS expects.
[[ -d /opt/homebrew/opt/libressl/bin ]] && path=(/opt/homebrew/opt/libressl/bin $path)

export PATH
