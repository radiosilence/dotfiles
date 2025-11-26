# Performance optimizations for Zsh
# Skip global compinit for faster startup
skip_global_compinit=1

#    ><(((º>   I loved Fish shell, but Zsh is my new home   <º)))><
#              Thanks for all the fish-y memories! 🐟→🚀

# Zsh options for performance
setopt NO_BEEP
setopt AUTO_CD
setopt GLOB_COMPLETE
setopt ALWAYS_TO_END
setopt COMPLETE_IN_WORD
setopt CORRECT
setopt EXTENDED_GLOB
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY
setopt INTERACTIVE_COMMENTS
setopt SHARE_HISTORY

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000

# Add custom completions to fpath before compinit
if [[ -d ~/.config/zsh/completions ]]; then
  fpath=(~/.config/zsh/completions $fpath)
fi

# Add brew completions (includes proper _git that sources git-completion.bash)
if [[ -d /opt/homebrew/share/zsh/site-functions ]]; then
  fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
fi

# Load completions
autoload -Uz compinit
compinit

# Force autoload of custom completions
if [[ -d ~/.config/zsh/completions ]]; then
  for completion in ~/.config/zsh/completions/_*; do
    [[ -r $completion ]] && autoload -Uz "${completion:t}"
  done
fi

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true

# Group completions by category with descriptions
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}── %d ──%f'
zstyle ':completion:*:messages' format '%F{purple}── %d ──%f'
zstyle ':completion:*:warnings' format '%F{red}── no matches ──%f'

# Colors for files/dirs (uses LS_COLORS)
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Nicer process completion
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*' force-list always

# Better SSH/SCP/rsync completion
zstyle ':completion:*:(ssh|scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-host' ignored-patterns '*(.|:)*' loopback ip6-loopback localhost ip6-localhost broadcasthost
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-domain' ignored-patterns '<->.<->.<->.<->' '^[-[:alnum:]]##(.[-[:alnum:]]##)##' '*@*'
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-ipaddr' ignored-patterns '^(<->.<->.<->.<->|(|-)eli-))'

# Man page sections
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.(^1*)' insert-sections true

# Cache completions (faster kubectl, docker, etc)
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zsh/completions

# Don't complete uninteresting users
zstyle ':completion:*:*:*:users' ignored-patterns \
  adm amanda apache avahi beaglidx bin cacti canna clamav daemon \
  dbus distcache dovecot fax ftp games gdm gkrellmd gopher \
  hacluster haldaemon halt hsqldb ident junkbust ldap lp mail \
  mailman mailnull mldonkey mysql nagios named netdump news nfsnobody \
  nobody nscd ntp nut nx openvpn operator pcap postfix postgres \
  privoxy pulse pvm quagga radvd rpc rpcuser rpm shutdown squid \
  sshd sync uucp vcsa xfs '_*'

# Git completion tweaks
zstyle ':completion:*:git-checkout:*' sort false

# fzf-tab config (if loaded)
zstyle ':fzf-tab:*' fzf-flags --height=50% --layout=reverse --border=rounded --info=inline
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd -1 --color=always $realpath 2>/dev/null || ls -1 --color=always $realpath'
zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --style=numbers --color=always --line-range=:100 $realpath 2>/dev/null || cat $realpath 2>/dev/null || lsd -1 --color=always $realpath 2>/dev/null || echo $desc'
zstyle ':fzf-tab:complete:kill:*' fzf-preview 'ps -p $word -o pid,user,%cpu,%mem,command --no-headers 2>/dev/null'
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word 2>/dev/null'
