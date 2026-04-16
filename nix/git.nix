{ pkgs, lib, ... }: {
  programs.git = {
    enable = true;

    # User identity is set in ~/.gitconfig.local (machine-specific, 1Password signing key)
    # Do NOT set userName/userEmail here — they differ per machine/org.

    lfs.enable = true;

    delta = {
      enable = true;
      options = {
        navigate = true;
        dark = true;
        line-numbers = true;
        side-by-side = false;
        syntax-theme = "Monokai Extended";
      };
    };

    signing = {
      signByDefault = true;
      format = "ssh";
      # macOS: 1Password desktop app handles signing
      # Linux: 1Password CLI or SSH agent (configured in local gitconfig)
      sshProgram = lib.mkIf pkgs.stdenv.isDarwin
        "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    };

    ignores = [
      # Claude overrides
      ".omc/"
      ".claude/*.local.*"
    ];

    extraConfig = {
      push = {
        default = "current";
        followTags = true;
        autoSetupRemote = true;
      };

      pull = {
        default = "current";
        rebase = false;
        merge = true;
      };

      core = {
        attributesfile = ".gitattributes";
      };

      init.defaultBranch = "main";

      alias.up = "pull --rebase --autostash";

      merge.conflictstyle = "zdiff3";

      interactive.diffFilter = "delta --color-only";

      # Diff colors
      "color \"diff\"" = {
        commit = "green";
        meta = "yellow";
        frag = "cyan";
        old = "red";
        new = "green";
        whitespace = "red reverse";
      };

      difftool.prompt = false;
    };
  };
}
