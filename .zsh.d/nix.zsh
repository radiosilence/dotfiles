if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
  . ~/.nix-profile/etc/profile.d/nix.sh

  if is_cmd direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
  fi
fi
