{ pkgs, dotfiles, ... }: {
  imports = [
    ./packages.nix
    ./git.nix
    ./ssh.nix
    ./zsh.nix
    ./programs.nix
    (import ./files.nix { inherit dotfiles; })
  ];

  home.stateVersion = "24.11";

  home.sessionVariables = {
    EDITOR = "hx";
    PAGER = "bat --style=plain";
    MANPAGER = "bat --style=plain --language=man";
    WORDCHARS = "*?_-.[]~=&;!#$%^(){}<>";
    HOMEBREW_BUNDLE_FILE = "~/Brewfile";
  };

  # Let home-manager manage itself
  programs.home-manager.enable = true;
}
