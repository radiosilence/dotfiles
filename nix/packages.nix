{ pkgs, ... }: {
  home.packages = with pkgs; [
    # ── Core CLI (was brew core.rb) ──────────────────────────────────
    git
    curl
    coreutils
    findutils
    gnupg
    cmake
    gnumake

    # ── File ops ─────────────────────────────────────────────────────
    fcp           # fast cp
    rsync
    aria2         # download accelerator
    unar          # universal unarchiver
    fd            # better find

    # ── Monitoring ───────────────────────────────────────────────────
    htop
    btop
    procs         # better ps
    dust          # better du
    tokei         # code stats

    # ── Search & Display ─────────────────────────────────────────────
    ripgrep
    jq
    yq-go
    glow          # markdown renderer
    xh            # better curl/httpie

    # ── Shell Tooling ────────────────────────────────────────────────
    sheldon       # zsh plugin manager (still used for cached eval on non-nix)
    starship      # prompt
    lsd           # better ls

    # ── Dev Tools ────────────────────────────────────────────────────
    gh            # github cli
    delta         # git diff pager
    lefthook      # git hooks
    shellcheck    # shell linter
    shfmt         # shell formatter

    # ── Misc ─────────────────────────────────────────────────────────
    cmatrix       # fun
    parallel      # GNU parallel
    fswatch       # file watcher
  ];
}
