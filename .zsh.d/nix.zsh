if [ -e /Users/jc/.nix-profile/etc/profile.d/nix.sh ]; then . /Users/jc/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer
if is_cmd direnv &>/dev/null; then
  eval "$(direnv hook zsh)"
fi
