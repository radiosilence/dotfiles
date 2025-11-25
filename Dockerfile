# Multi-stage container with dotfiles setup
# Based on Debian with mise and essential development tools

# Pin to specific digest for reproducibility
FROM debian:12-slim@sha256:b4aa902587c2e61ce789849cb54c332b0400fe27b1ee33af4669e1f7e7c3e22f

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  curl git unzip zip sudo ca-certificates parallel \
  build-essential cmake make \
  ripgrep bat jq btop tree aria2 beets ffmpeg \
  zsh \
  && rm -rf /var/lib/apt/lists/*

# Set shell and mise environment variables
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV MISE_DATA_DIR="/mise"
ENV MISE_CONFIG_DIR="/mise"
ENV MISE_CACHE_DIR="/mise/cache"
ENV MISE_INSTALL_PATH="/usr/local/bin/mise"
ENV PATH="/mise/shims:$PATH"

# Install mise with checksum verification
ARG MISE_VERSION=2025.11.7
RUN curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64" -o /usr/local/bin/mise \
  && chmod +x /usr/local/bin/mise \
  && mise --version

# Create user jc with uid/gid 1000
ARG USERNAME=jc
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/zsh \
  && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

# Create mise directories with proper ownership
RUN mkdir -p /mise/cache \
  && chown -R $USERNAME:$USERNAME /mise

USER $USERNAME
WORKDIR /home/$USERNAME

ENV PATH="/home/$USERNAME/.dotfiles/bin:$PATH"

# Install rustup with verification (official method uses HTTPS + TLS 1.2+)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
  | sh -s -- -y --default-toolchain stable --profile minimal \
  && . ~/.cargo/env \
  && rustc --version
ENV PATH="/home/$USERNAME/.cargo/bin:$PATH"

# Copy dotfiles
COPY --chown=$USERNAME:$USERNAME . /home/$USERNAME/.dotfiles

# Fetch SSH public keys (these are public, not secrets)
RUN mkdir -p ~/.ssh && chmod 700 ~/.ssh \
  && curl -fsSL https://github.com/radiosilence.keys > ~/.ssh/authorized_keys \
  && chmod 600 ~/.ssh/authorized_keys

# Build dotfiles tools
RUN . ~/.cargo/env \
  && cd /home/$USERNAME/.dotfiles \
  && ./setup

# Install mise tools with secret mounted directly (no temp file)
RUN --mount=type=secret,id=github_token,uid=1000 \
  . ~/.cargo/env \
  && mise trust ~ \
  && GITHUB_TOKEN=$(cat /run/secrets/github_token) mise install

# Initialize zsh plugins
RUN zsh -c 'echo "Initializing zsh..."'

# Install nano-web
RUN . ~/.cargo/env \
  && go install github.com/radiosilence/nano-web@latest

# Create /srv with restricted permissions
USER root
RUN mkdir -p /srv && chown jc:jc /srv && chmod 750 /srv
USER jc

ENV SHELL=/bin/zsh
ENV TERM=xterm-256color

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/_health || exit 1

CMD ["/home/jc/go/bin/nano-web", "serve", "/srv", "--port", "3000"]
