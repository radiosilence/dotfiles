{ pkgs, ... }: {
  # ── Nix Settings ─────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "james.cleveland" ];
  };
  nix.optimise.automatic = true;

  # Use nix-darwin to manage the nix-daemon
  services.nix-daemon.enable = true;

  # Allow unfree packages (1password, etc.)
  nixpkgs.config.allowUnfree = true;

  # ── macOS System ─────────────────────────────────────────────────────
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };
    finder = {
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
    };
  };

  # ── Homebrew (casks + remaining formulae) ────────────────────────────
  # nix-darwin manages brew declaratively — it runs `brew bundle` on switch.
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap"; # remove anything not declared here
    };

    taps = [
      "buo/cask-upgrade"
    ];

    # Formulae that must stay in brew (system integration, libs for mise runtimes)
    brews = [
      "zsh"           # system shell registration
      "mise"          # project-level runtimes
      "pam-reattach"  # Touch ID in tmux
      "openssl@3"
      "llvm"
      "uv"
      # Libs needed by mise-managed runtimes
      "gmp"
      "libyaml"
      "ossp-uuid"
      "readline"
      "xz"
    ];

    # Core casks — always installed
    casks = [
      "1password"
      "1password-cli"
      "ghostty"
    ];

    # masApps = {
    #   Infuse = 1136220934;
    # };
  };

  # ── Shell ────────────────────────────────────────────────────────────
  # Ensure nix-managed zsh is in /etc/shells (brew zsh handles this via brew)
  programs.zsh.enable = true;

  # Used for backwards compat — the state version at first `darwin-rebuild switch`
  system.stateVersion = 6;
}
