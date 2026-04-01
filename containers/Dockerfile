# syntax=docker/dockerfile:1
FROM ubuntu:latest

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

# Bootstrap: curl + certs + git + zsh + build deps + sudo
# Erlang runtime deps included (libwx, libssl, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    build-essential \
    ca-certificates \
    curl \
    fop \
    git \
    gnupg \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libncurses5-dev \
    libpng-dev \
    libssh-dev \
    libssl-dev \
    openssh-client \
    pkg-config \
    sudo \
    unixodbc-dev \
    unzip \
    wget \
    xsltproc \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user with sudo
# Ubuntu 24.04 ships with uid/gid 1000 as 'ubuntu' — nuke it
RUN userdel -r ubuntu 2>/dev/null; \
    groupdel ubuntu 2>/dev/null; \
    groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/zsh $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copy dotfiles repo
COPY --chown=$USERNAME:$USERNAME . /home/$USERNAME/.dotfiles

USER $USERNAME
ENV HOME=/home/$USERNAME
WORKDIR $HOME

# Install mise
RUN curl https://mise.run | sh

ENV PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

# Converge — mise installs all tools from config.d/mise/config.toml,
# links dotfiles, installs tmux plugins, sheldon, completions, etc.
RUN --mount=type=secret,id=gh_pat \
    export GITHUB_TOKEN=$(cat /run/secrets/gh_pat 2>/dev/null || true) \
    && cd ~/.dotfiles && task converge

# Container-specific: safe npm defaults
COPY --chown=$USERNAME:$USERNAME containers/config/.npmrc $HOME/.npmrc

WORKDIR /home/$USERNAME

CMD ["zsh"]
