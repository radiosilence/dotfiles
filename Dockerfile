# Multi-stage container with dotfiles setup
# Based on Debian with mise and essential development tools
FROM debian:12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  # Essential tools
  curl git unzip zip sudo ca-certificates \
  # Build tools
  build-essential cmake make \
  # CLI utilities (not managed by mise)
  ripgrep bat jq btop tree aria2 beets ffmpeg \
  # Shell
  zsh \
  # Clean up
  && rm -rf /var/lib/apt/lists/*

# Set shell and mise environment variables (from mise cookbook)
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV MISE_DATA_DIR="/mise"
ENV MISE_CONFIG_DIR="/mise"
ENV MISE_CACHE_DIR="/mise/cache"
ENV MISE_INSTALL_PATH="/usr/local/bin/mise"
ENV PATH="/mise/shims:$PATH"

# GitHub token will be provided via secret mount (not leaked into final image)

# Install mise globally (from mise cookbook)
RUN curl https://mise.run | sh




# Create user jc with uid/gid 1000
ARG USERNAME=jc
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/zsh \
  && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

# Create mise directories with proper ownership
RUN mkdir -p /mise/cache \
  && chown -R $USERNAME:$USERNAME /mise

# Switch to user
USER $USERNAME
WORKDIR /home/$USERNAME

# Set PATH for dotfiles
ENV PATH="/home/$USERNAME/.dotfiles/bin:$PATH"

# Install rustup/cargo as user so mise can use cargo backend
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable \
  && . ~/.cargo/env
ENV PATH="/home/$USERNAME/.cargo/bin:$PATH"

# Copy dotfiles directly to final location
COPY --chown=$USERNAME:$USERNAME . /home/$USERNAME/.dotfiles

# Create SSH directory and download authorized keys
RUN mkdir -p ~/.ssh && chmod 700 ~/.ssh \
  && curl -fsSL https://github.com/radiosilence.keys > ~/.ssh/authorized_keys \
  && chmod 600 ~/.ssh/authorized_keys

# Add PATH configuration to zshrc (similar to setup-macos)
RUN echo 'export PATH="$HOME/.dotfiles/bin:$PATH"' >> ~/.zshrc

# Make scripts executable and run install
RUN chmod +x /home/$USERNAME/.dotfiles/bin/* \
  && /home/$USERNAME/.dotfiles/install

# Switch to root to access secret and copy to user-readable location
USER root
RUN --mount=type=secret,id=github_token \
  cp /run/secrets/github_token /tmp/github_token \
  && chown jc:jc /tmp/github_token \
  && chmod 600 /tmp/github_token

# Switch back to user and install tools via mise (with GitHub token)
USER jc
RUN . ~/.cargo/env \
  && GITHUB_TOKEN=$(cat /tmp/github_token) GH_TOKEN=$(cat /tmp/github_token) mise trust ~ \
  && GITHUB_TOKEN=$(cat /tmp/github_token) GH_TOKEN=$(cat /tmp/github_token) mise install \
  && rm /tmp/github_token





# Run zsh once to initialize plugins and first-run setup
RUN zsh -c 'echo "Initializing zsh and plugins..."'

# Container-specific configurations
ENV SHELL=/bin/zsh
ENV TERM=xterm-256color

# Default to zsh shell
CMD ["/bin/zsh"]