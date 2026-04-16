{ dotfiles }: { pkgs, ... }: {
  # ── Config directories (replaces link:config task) ───────────────────
  # These are managed as symlinks to the repo's config.d/ directory.
  # home-manager creates the symlinks on `darwin-rebuild switch`.
  xdg.configFile = {
    # Terminal & multiplexer
    "ghostty".source = "${dotfiles}/config.d/ghostty";
    "zellij".source = "${dotfiles}/config.d/zellij";

    # Editors (helix managed by programs.helix, but zed stays as file)
    "zed".source = "${dotfiles}/config.d/zed";

    # Tools
    "k9s".source = "${dotfiles}/config.d/k9s";
    "btop".source = "${dotfiles}/config.d/btop";
    "gitmux".source = "${dotfiles}/config.d/gitmux";
    "koan".source = "${dotfiles}/config.d/koan";
    "mise".source = "${dotfiles}/config.d/mise";
    "beets".source = "${dotfiles}/config.d/beets";
    "harper-ls".source = "${dotfiles}/config.d/harper-ls";
    "browser-schedule".source = "${dotfiles}/config.d/browser-schedule";

    # Zsh conf.d — only the complex files that weren't inlined into zsh.nix
    "zsh/conf.d/git.zsh".source = "${dotfiles}/config.d/zsh/conf.d/git.zsh";
    "zsh/conf.d/git-worktree.zsh".source = "${dotfiles}/config.d/zsh/conf.d/git-worktree.zsh";
    "zsh/conf.d/k8s.zsh".source = "${dotfiles}/config.d/zsh/conf.d/k8s.zsh";

    # Zsh custom functions
    "zsh/functions/echo-to-file".source = "${dotfiles}/config.d/zsh/functions/echo-to-file";
    "zsh/functions/fm".source = "${dotfiles}/config.d/zsh/functions/fm";
    "zsh/functions/fonts!".source = "${dotfiles}/config.d/zsh/functions/fonts!";
    "zsh/functions/fr".source = "${dotfiles}/config.d/zsh/functions/fr";
    "zsh/functions/gen-diff".source = "${dotfiles}/config.d/zsh/functions/gen-diff";
    "zsh/functions/install-terminfo".source = "${dotfiles}/config.d/zsh/functions/install-terminfo";
    "zsh/functions/take".source = "${dotfiles}/config.d/zsh/functions/take";
    "zsh/functions/taketmp".source = "${dotfiles}/config.d/zsh/functions/taketmp";
    "zsh/functions/using".source = "${dotfiles}/config.d/zsh/functions/using";
  };

  # ── Home directory dotfiles (replaces link:dotfiles task) ────────────
  home.file = {
    ".tmux.conf".source = "${dotfiles}/.tmux.conf";
    ".wezterm.lua".source = "${dotfiles}/.wezterm.lua";
    ".editorconfig".source = "${dotfiles}/.editorconfig";
    ".bunfig.toml".source = "${dotfiles}/.bunfig.toml";

    # Cargo security config (replaces link:cargo task)
    ".cargo/config.toml".source = "${dotfiles}/packager.d/cargo-config.toml";

    # Brewfile (replaces link:brewfile task)
    "Brewfile".source = "${dotfiles}/Brewfile";
  };
}
