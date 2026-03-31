# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

# GitHub CLI repo
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list

# System packages — mirrors core.rb + dev.rb brew setup for Linux
# Erlang/OTP build deps included (libwx, libssl, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    aria2 \
    autoconf \
    build-essential \
    ca-certificates \
    cmake \
    clang-format \
    curl \
    fop \
    gh \
    git \
    gnupg \
    htop \
    btop \
    inotify-tools \
    jq \
    jsonnet \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libgmp-dev \
    liblzma-dev \
    libncurses5-dev \
    libpng-dev \
    libpq-dev \
    libreadline-dev \
    libssh-dev \
    libssl-dev \
    libwxgtk3.2-dev \
    libwxgtk-webview3.2-dev \
    libyaml-dev \
    llvm \
    luarocks \
    openssh-client \
    parallel \
    pkg-config \
    postgresql-client \
    rsync \
    sudo \
    tmux \
    unixodbc-dev \
    unzip \
    uuid-dev \
    wget \
    xsltproc \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user with sudo (needed for `task converge` apt:upgrade)
# Ubuntu 24.04 ships with uid/gid 1000 as 'ubuntu' — remove it first
RUN userdel -r ubuntu 2>/dev/null; \
    groupdel ubuntu 2>/dev/null; \
    groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/zsh $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install go-task globally
RUN sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

# Container entrypoint
COPY containers/scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy dotfiles repo (build context is repo root)
COPY --chown=$USERNAME:$USERNAME . /home/$USERNAME/.dotfiles

USER $USERNAME
ENV HOME=/home/$USERNAME
WORKDIR $HOME

# Install mise
RUN --mount=type=secret,id=gh_pat \
    GITHUB_TOKEN=$(cat /run/secrets/gh_pat 2>/dev/null || true) \
    curl https://mise.run | sh

ENV PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

# Install all language toolchains via mise
RUN --mount=type=secret,id=gh_pat \
    GITHUB_TOKEN=$(cat /run/secrets/gh_pat 2>/dev/null || true) \
    mise use --global \
        node@lts \
        bun@latest \
        erlang@27 \
        elixir@1.18 \
        rust@stable \
        go@latest \
        uv@latest \
        awscli@latest \
        terraform@latest

# Node: corepack for pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Elixir: hex + rebar (before converge, as some tasks may need mix)
RUN mix local.hex --force && mix local.rebar --force

# Converge dotfiles — links, tmux plugins, sheldon, completions, bins, etc.
# Platform guards auto-skip macOS-only tasks (brew, fonts, 1password, rosetta)
RUN --mount=type=secret,id=gh_pat \
    export GITHUB_TOKEN=$(cat /run/secrets/gh_pat 2>/dev/null || true) \
    && cd ~/.dotfiles && task converge

# Container-specific: safe npm defaults (overrides any .npmrc from converge)
COPY --chown=$USERNAME:$USERNAME containers/config/.npmrc $HOME/.npmrc

# Rust-installed CLI tools (brew equivalents + supply chain security)
RUN cargo install cargo-audit cargo-deny sheldon tokei
RUN go install golang.org/x/vuln/cmd/govulncheck@latest

# Go safe defaults
ENV GOPROXY=https://proxy.golang.org,direct
ENV GONOSUMCHECK=""
ENV GONOSUMDB=""

# Trust /workspace for project mise configs
RUN mise settings trusted_config_paths=/workspace

WORKDIR /workspace
ENTRYPOINT ["entrypoint.sh"]
CMD ["zsh"]
