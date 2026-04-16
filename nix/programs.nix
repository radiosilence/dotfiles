{ pkgs, ... }: {
  # ── Starship Prompt ──────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;

      format = builtins.concatStringsSep "" [
        "$username"
        "$hostname"
        "$localip"
        "$singularity"
        "$kubernetes"
        "$directory"
        "\${custom.git_email}"
        "$git_branch"
        "$git_commit"
        "$git_state"
        "$git_metrics"
        "$git_status"
        "$docker_context"
        "$package"
        "$c"
        "$cmake"
        "$container"
        "$elixir"
        "$gleam"
        "$golang"
        "$kotlin"
        "$lua"
        "$nodejs"
        "$pulumi"
        "$python"
        "$ruby"
        "$rust"
        "$terraform"
        "$buf"
        "$memory_usage"
        "$aws"
        "$nats"
        "$direnv"
        "$env_var"
        "$mise"
        "$sudo"
        "$cmd_duration"
        "$line_break"
        "$jobs"
        "$battery"
        "$status"
        "$os"
        "\n"
        "$shell"
        "$character"
      ];

      character = {
        error_symbol = "[](red)";
        success_symbol = "[](green)";
      };

      directory = {
        truncation_length = 8;
        truncate_to_repo = false;
        read_only = "";
        style = "fg:8";
        truncation_symbol = ".../";
      };

      hostname.format = "[$hostname]($style) ";
      username = {
        format = "[$user]($style)@";
        show_always = false;
      };

      custom.git_email = {
        when = "git rev-parse --git-dir";
        format = "[ $output]($style) ";
        style = "dim";
        shell = [ "git" "config" "user.email" ];
      };

      git_branch = {
        symbol = " ";
        format = "[$symbol$branch]($style) ";
        style = "green";
      };

      docker_context.disabled = true;
      container = {
        format = " ";
        disabled = false;
      };

      golang.symbol = "󰟓 ";
      nodejs = {
        symbol = " ";
        disabled = false;
        style = "green";
      };

      package = {
        disabled = true;
        display_private = true;
        symbol = "  ";
      };

      cmd_duration.min_time = 2000;

      aws = {
        format = "[$symbol($profile )(\\($region\\) )(\\[$duration\\] )]($style)";
        symbol = " ";
      };

      kubernetes = {
        disabled = false;
        format = "[$symbol$context( \\($namespace\\))]($style) ";
        symbol = "󱃾 ";
      };

      ruby.symbol = " ";
      rust.symbol = " ";
      elixir.symbol = " ";
      python.symbol = " ";
      terraform.symbol = "󱁢 ";
    };
  };

  # ── FZF ──────────────────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--height=50%"
      "--layout=reverse"
      "--border=rounded"
      "--info=inline"
    ];
  };

  # ── Bat ──────────────────────────────────────────────────────────────
  programs.bat = {
    enable = true;
    config = {
      theme = "Monokai Extended";
      style = "numbers";
    };
  };

  # ── Zoxide ───────────────────────────────────────────────────────────
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── Broot ────────────────────────────────────────────────────────────
  programs.broot = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── Helix ────────────────────────────────────────────────────────────
  programs.helix = {
    enable = true;
    settings = {
      theme = "monokai_pro";

      editor = {
        auto-format = true;
        true-color = true;
        color-modes = true;
        bufferline = "always";
        cursorline = true;
        rulers = [ 120 ];
        end-of-line-diagnostics = "hint";
        line-number = "relative";
        idle-timeout = 250;
        popup-border = "all";

        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        soft-wrap.enable = true;

        inline-diagnostics.cursor-line = "error";

        indent-guides = {
          render = true;
          character = "│";
          skip-levels = 1;
        };

        whitespace.render = {
          space = "all";
          tab = "all";
          nbsp = "all";
          newline = "none";
        };

        file-picker.hidden = false;
        lsp.display-messages = true;

        auto-save = {
          focus-lost = true;
          after-delay = {
            enable = true;
            timeout = 3000;
          };
        };

        search = {
          smart-case = true;
          wrap-around = true;
        };

        smart-tab.enable = true;

        statusline = {
          left = [ "mode" "spinner" "version-control" "file-name" "read-only-indicator" "file-modification-indicator" ];
          center = [ ];
          right = [ "diagnostics" "selections" "register" "position" "file-type" ];
        };
      };

      keys.normal = {
        "A-w" = ":bc";
        "A-W" = ":wbc";
        "A-tab" = ":buffer-next";
        "A-S-tab" = ":buffer-previous";
        "C-r" = ":reload";
      };
    };

    languages = {
      language-server = {
        rust-analyzer.config = {
          checkOnSave.command = "clippy";
        };
        ruff = {
          command = "ruff";
          args = [ "server" ];
        };
        tsgo = {
          command = "tsgo";
          args = [ "lsp" ];
        };
        yaml-language-server.config = {
          yaml = {
            validation = true;
            schemaStore.enable = true;
          };
        };
      };

      language = [
        { name = "rust"; auto-format = true; }
        { name = "python"; auto-format = true; language-servers = [ "pyright" "ruff" ]; formatter = { command = "ruff"; args = [ "format" "-" ]; }; }
        { name = "go"; auto-format = true; }
        { name = "elixir"; auto-format = true; }
        { name = "lua"; auto-format = true; formatter = { command = "stylua"; args = [ "-" ]; }; }
        { name = "toml"; auto-format = true; }
        { name = "yaml"; auto-format = true; }
        { name = "json"; auto-format = true; formatter = { command = "prettier"; args = [ "--parser" "json" ]; }; }
        { name = "markdown"; auto-format = true; formatter = { command = "prettier"; args = [ "--parser" "markdown" ]; }; }
        { name = "html"; auto-format = true; formatter = { command = "prettier"; args = [ "--parser" "html" ]; }; }
        { name = "css"; auto-format = true; formatter = { command = "prettier"; args = [ "--parser" "css" ]; }; }
        { name = "scss"; auto-format = true; formatter = { command = "prettier"; args = [ "--parser" "scss" ]; }; }
        { name = "bash"; auto-format = true; formatter = { command = "shfmt"; }; }
        { name = "javascript"; auto-format = true; formatter = { command = "prettier"; args = [ "--parser" "typescript" ]; }; language-servers = [ "tsgo" "vscode-eslint-language-server" ]; }
        { name = "typescript"; auto-format = true; formatter = { command = "prettier"; args = [ "--parser" "typescript" ]; }; language-servers = [ "tsgo" "vscode-eslint-language-server" ]; }
        { name = "tsx"; auto-format = true; formatter = { command = "prettier"; args = [ "--parser" "typescript" ]; }; language-servers = [ "tsgo" "vscode-eslint-language-server" ]; }
        { name = "jsx"; auto-format = true; formatter = { command = "prettier"; args = [ "--parser" "typescript" ]; }; language-servers = [ "tsgo" "vscode-eslint-language-server" ]; }
        { name = "jsonnet"; auto-format = true; }
        { name = "dockerfile"; auto-format = true; }
        { name = "hcl"; auto-format = true; }
        { name = "protobuf"; auto-format = true; formatter = { command = "buf"; args = [ "format" ]; }; }
      ];
    };
  };

  # ── Tmux (keep existing config file) ─────────────────────────────────
  # tmux config is complex with themes — managed via home.file in files.nix
  # Programs like tmux-resurrect and tmux-fzf-url are git-cloned plugins,
  # kept in Taskfile for now.
}
