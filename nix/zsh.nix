{ pkgs, ... }: {
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    autocd = true;

    history = {
      size = 50000;
      save = 50000;
      path = "$HOME/.zsh_history";
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      share = true;
      extended = false;
    };

    historySubstringSearch.enable = true;

    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;

    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.fetchFromGitHub {
          owner = "Aloxaf";
          repo = "fzf-tab";
          rev = "v1.1.2";
          sha256 = "sha256-Qv8zAiMtrr67CbLRrFjGaPzFZcOiMVEFLg1Z+N6VMhg=";
        };
      }
      {
        name = "zsh-completions";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-completions";
          rev = "0.35.0";
          sha256 = "sha256-GFHlZjIHUWwyeVoCpszgn4AmLPSSE8UVNfRmisnhkpg=";
        };
      }
      {
        name = "claude-code-completion";
        src = pkgs.fetchFromGitHub {
          owner = "1160054";
          repo = "claude-code-zsh-completion";
          rev = "main";
          sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        };
      }
    ];

    # ── Shell Aliases ──────────────────────────────────────────────────
    shellAliases = {
      # LSD (better ls)
      lsd = "lsd -A --color=always --icon=always --hyperlink=auto";
      l = "lsd -A --color=always --icon=always --hyperlink=auto";
      ls = "lsd -A --color=always --icon=always --hyperlink=auto";
      ll = "lsd -Al --color=always --icon=always --hyperlink=auto";
      tree = "lsd --tree";

      # Bat (better cat)
      cat = "bat";
      bat = ''bat --map-syntax="*.kubeconfig:YAML" --map-syntax="config:YAML"'';

      # NPM
      nr = "npm run";
      n = "npm";
      nd = "npm run dev";
      ni = "npm install";

      # PNPM
      p = "pnpm";
      pi = "pnpm install";
      pt = "pnpm test";
      ptu = "pnpm test -u";
      pa = "pnpm add";
      paW = "pnpm add -W";
      paD = "pnpm add -D";
      paDW = "pnpm add -DW";

      # Bun
      b = "bun";
      bi = "bun install";
      bt = "bun test";
      btu = "bun test -u";
      ba = "bun add";
      baW = "bun add -W";
      baD = "bun add -D";
      baDW = "bun add -DW";
      bs = "bun && bun start";

      # Claude
      claude = "claude --dangerously-skip-permissions";
      c = "claude --dangerously-skip-permissions";

      # Brew
      bb = "brew bundle";

      # Mise
      m = "mise";
      mi = "mise i";

      # AWS
      aws-shell = "aws-vault exec -d 72h -n";
      aws-login = "aws-vault login -d 72h";

      # GitHub
      ghprv = "gh pr view";
      ghprb = "gh pr view --web";
      ghprcw = "gh pr checks --watch";
      ccr = ''gh pr comment --body "@claude review"'';
      ccrf = ''gh pr comment --body "@claude review and fix all issues"'';
      ccrr = ''gh pr comment --body "@claude re-review"'';
      ccrrf = ''gh pr comment --body "@claude re-review and fix all outstanding issues"'';

      # Zellij
      zj = "zellij";

      # Misc
      listening = "lsof -iTCP -sTCP:LISTEN -P -n";
      sizes = "dust -d 2";

      # Converge
      upd = "converge";
    };

    # ── initExtraFirst ─────────────────────────────────────────────────
    # Runs before compinit and plugin loading.
    initExtraFirst = ''
      # Skip global compinit for faster startup
      skip_global_compinit=1

      # Deduplicate PATH and FPATH
      typeset -U path fpath
    '';

    # ── initExtra ──────────────────────────────────────────────────────
    # Runs after compinit and plugins. Order matters — kept close to original conf.d numbering.
    initExtra = ''
      # ── Options (was 00-prelude.zsh, partially) ──────────────────────
      setopt NO_BEEP
      setopt GLOB_COMPLETE
      setopt ALWAYS_TO_END
      setopt COMPLETE_IN_WORD
      setopt CORRECT
      setopt EXTENDED_GLOB
      setopt HIST_REDUCE_BLANKS
      setopt HIST_SAVE_NO_DUPS
      setopt HIST_VERIFY
      setopt INC_APPEND_HISTORY
      setopt INTERACTIVE_COMMENTS
      setopt BANG_HIST

      # ── Cache eval helper (from 00-prelude) ──────────────────────────
      _cached_eval() {
        local name=$1 cmd=$2 dep=$3
        local cache_dir=~/.cache/zsh/eval
        local cache_file="$cache_dir/$name.zsh"
        [[ -d $cache_dir ]] || mkdir -p "$cache_dir"
        if [[ ! -f $cache_file ]] || { [[ -n $dep ]] && [[ $dep -nt $cache_file ]]; }; then
          eval "$cmd" > "$cache_file"
        fi
        source "$cache_file"
      }

      # ── Custom completions fpath ─────────────────────────────────────
      if [[ -d ~/.config/zsh/completions ]]; then
        fpath=(~/.config/zsh/completions $fpath)
      fi

      # ── Brew completions fpath ───────────────────────────────────────
      for _brew_zsh in /opt/homebrew/share/zsh/site-functions /usr/local/share/zsh/site-functions; do
        if [[ -d $_brew_zsh ]]; then
          fpath=($_brew_zsh $fpath)
          break
        fi
      done
      unset _brew_zsh

      # ── Completion styling (from 00-prelude) ─────────────────────────
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
      zstyle ':completion:*' special-dirs true
      zstyle ':completion:*' squeeze-slashes true
      zstyle ':completion:*' group-name '''
      zstyle ':completion:*:descriptions' format '%F{yellow}── %d ──%f'
      zstyle ':completion:*:messages' format '%F{purple}── %d ──%f'
      zstyle ':completion:*:warnings' format '%F{red}── no matches ──%f'
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
      zstyle ':completion:*:*:kill:*' menu yes select
      zstyle ':completion:*:kill:*' force-list always
      zstyle ':completion:*:(ssh|scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
      zstyle ':completion:*:(ssh|scp|rsync):*:hosts-host' ignored-patterns '*(.|:)*' loopback ip6-loopback localhost ip6-localhost broadcasthost
      zstyle ':completion:*:(ssh|scp|rsync):*:hosts-domain' ignored-patterns '<->.<->.<->.<->' '^[-[:alnum:]]##(.[-[:alnum:]]##)##' '*@*'
      zstyle ':completion:*:(ssh|scp|rsync):*:hosts-ipaddr' ignored-patterns '^(<->.<->.<->.<->|(|-)eli-*)'
      zstyle ':completion:*:manuals' separate-sections true
      zstyle ':completion:*:manuals.(^1*)' insert-sections true
      zstyle ':completion:*' use-cache on
      zstyle ':completion:*' cache-path ~/.cache/zsh/completions
      zstyle ':completion:*:*:*:users' ignored-patterns \
        adm amanda apache avahi beaglidx bin cacti canna clamav daemon \
        dbus distcache dovecot fax ftp games gdm gkrellmd gopher \
        hacluster haldaemon halt hsqldb ident junkbust ldap lp mail \
        mailman mailnull mldonkey mysql nagios named netdump news nfsnobody \
        nobody nscd ntp nut nx openvpn operator pcap postfix postgres \
        privoxy pulse pvm quagga radvd rpc rpcuser rpm shutdown squid \
        sshd sync uucp vcsa xfs '_*'
      zstyle ':completion:*:git-checkout:*' sort false

      # fzf-tab config
      zstyle ':fzf-tab:*' fzf-flags --height=50% --layout=reverse --border=rounded --info=inline
      zstyle ':fzf-tab:*' switch-group '<' '>'
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd -1 --color=always $realpath 2>/dev/null || ls -1 --color=always $realpath'
      zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --style=numbers --color=always --line-range=:100 $realpath 2>/dev/null || cat $realpath 2>/dev/null || lsd -1 --color=always $realpath 2>/dev/null || echo $desc'
      zstyle ':fzf-tab:complete:kill:*' fzf-preview 'ps -p $word -o pid,user,%cpu,%mem,command --no-headers 2>/dev/null'
      zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word 2>/dev/null'

      # ── PATH (was 10-path.zsh + dotfiles.zsh) ────────────────────────
      path=(~/.local/bin ~/.dotfiles/bin ~/.dotfiles/scripts $path)
      export PATH

      # ── Brew (was 15-brew.zsh) ───────────────────────────────────────
      if [[ -d /opt/homebrew ]]; then
        export BREW_PREFIX=/opt/homebrew
      else
        export BREW_PREFIX=/usr/local
      fi
      path=("$BREW_PREFIX/bin" "$BREW_PREFIX/sbin" $path)
      export PATH

      # ── 1Password (was 20-op.zsh) ───────────────────────────────────
      [[ -f ~/.config/op/plugins.sh ]] && source ~/.config/op/plugins.sh

      # ── Mise (was 25-mise.zsh) ──────────────────────────────────────
      if command -v mise >/dev/null; then
        _cached_eval "mise" "mise activate zsh"
      fi

      # ── GitHub token (was github.zsh) ───────────────────────────────
      if [[ -z $GITHUB_TOKEN ]] && command -v gh >/dev/null && gh auth status &>/dev/null; then
        export GITHUB_TOKEN=$(gh auth token 2>/dev/null)
      fi

      # ── GCP (was gcp.zsh) ──────────────────────────────────────────
      if command -v gcloud >/dev/null; then
        export USE_GKE_GCLOUD_AUTH_PLUGIN=True
      fi

      # ── libpq (was libpq.zsh) ──────────────────────────────────────
      if [[ -d /opt/homebrew/opt/libpq ]]; then
        export LDFLAGS="''${LDFLAGS} -L/opt/homebrew/opt/libpq/lib"
        export CPPFLAGS="''${CPPFLAGS} -I/opt/homebrew/opt/libpq/include"
        path=(/opt/homebrew/opt/libpq/bin $path)
      fi

      # ── OrbStack (was orbstack.zsh) ─────────────────────────────────
      [[ -f ~/.orbstack/shell/init.zsh ]] && source ~/.orbstack/shell/init.zsh

      # ── Terraform (was terraform.zsh) ───────────────────────────────
      if command -v terraform >/dev/null; then
        autoload -U +X bashcompinit && bashcompinit
        complete -o nospace -C terraform terraform
      fi

      # ── Bun completions ─────────────────────────────────────────────
      [ -s ~/.bun/_bun ] && source ~/.bun/_bun

      # ── npm-add-safe (was claude.zsh) ───────────────────────────────
      npm-add-safe() {
        claude --allow-dangerously-skip-permissions -p "please checkout the git repo for npm package $1, audit the code and it's dependencies, and if it seems reasonable, run npm add $1. You are NOT being run interactively, if the package seems safe, add it, do not ask questions."
      }

      # ── Utility functions (was utils.zsh) ───────────────────────────
      whatport() { lsof -i :"$1"; }

      if command -v fd >/dev/null; then
        recent() { fd --type f --changed-within "''${1:-1h}" | head -20; }
      fi

      if command -v procs >/dev/null; then
        psg() { procs --tree | grep -i "$1"; }
      fi

      if command -v zellij >/dev/null && command -v fzf >/dev/null; then
        zp() {
          local sessions selected target name
          local ic_s=$'\uf489' ic_d=$'\uf07c'
          sessions=$(zellij list-sessions --short 2>/dev/null)
          selected=$(
            {
              if [ -n "$sessions" ]; then
                echo "$sessions" | while IFS= read -r s; do
                  [ -n "$s" ] && printf "\e[32m%s %s\e[0m\n" "$ic_s" "$s"
                done
              fi
              zoxide query --list 2>/dev/null | head -20 | while IFS= read -r d; do
                [ -n "$d" ] && printf "\e[34m%s %s\e[0m\n" "$ic_d" "''${d/#$HOME/~}"
              done
            } | fzf --ansi --reverse --header="zellij sessions / dirs" \
                    --preview 'p=$(echo {} | sed "s/^[^ ]* //"); p="''${p/#\~/$HOME}"; [ -d "$p" ] && mise x -- lsd -A --color=always --icon=always --tree --depth 2 "$p" 2>/dev/null || ls "$p" 2>/dev/null || echo "session: $p"'
          )
          [ -z "$selected" ] && return
          target="''${selected#* }"
          if [ -n "$sessions" ] && echo "$sessions" | grep -qxF "$target"; then
            zellij attach "$target"
          else
            target="''${target/#\~/$HOME}"
            name=$(basename "$target")
            cd "$target" && zellij attach -c "$name"
          fi
        }
      fi

      if command -v glow >/dev/null && command -v fd >/dev/null && command -v fzf >/dev/null; then
        gzf() { glow "$(fd -e md | fzf --ansi --reverse --preview 'glow -s dark {}')"; }
      fi

      converge() {
        git -C ~/.dotfiles pull --quiet
        [[ $(uname) == "Linux" ]] && sudo -v 2>/dev/null
        task --taskfile ~/.dotfiles/Taskfile.yml converge
      }

      # ── Custom zsh functions ─────────────────────────────────────────
      if [[ -d ~/.config/zsh/functions ]]; then
        fpath=(~/.config/zsh/functions $fpath)
        autoload -Uz ~/.config/zsh/functions/*(.:t)
      fi

      # ── Interactive keybindings (was interactive.zsh) ────────────────
      if [[ $- == *i* ]]; then
        bindkey '^[^?' backward-kill-word
        bindkey '^[[1;3D' backward-word
        bindkey '^[[1;3C' forward-word
        bindkey '^C' kill-whole-line
      fi

      # ── Source remaining conf.d files ────────────────────────────────
      # Complex configs that stay as files: git, git-worktree, k8s
      for config in ~/.config/zsh/conf.d/*.zsh; do
        [[ -r "$config" ]] && source "$config"
      done

      # ── Zed MCP secrets ─────────────────────────────────────────────
      [[ -f ~/.config/zed/.secrets ]] && source ~/.config/zed/.secrets

      # ── Auto-compile for faster loads ───────────────────────────────
      {
        local f
        for f in ~/.config/zsh/conf.d/*.zsh ~/.cache/zsh/eval/*.zsh(N); do
          if [[ ! -f "$f.zwc" ]] || [[ "$f" -nt "$f.zwc" ]]; then
            zcompile "$f" 2>/dev/null
          fi
        done
      } &!
    '';
  };
}
