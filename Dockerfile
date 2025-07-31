# Multi-stage container with dotfiles setup
# Based on Ubuntu with essential development tools
FROM ubuntu:24.04 AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
  # Essential tools
  curl wget git unzip zip \
  # Build tools
  build-essential cmake make \
  # Languages & runtimes
  nodejs npm python3 python3-pip \
  # CLI utilities
  ripgrep fd-find bat fzf jq \
  htop btop tree \
  # Important CLI tools
  aria2 \
  beets \
  yt-dlp \
  ffmpeg \
  # Network tools
  curl wget netcat-openbsd \
  # Text processing
  sed awk \
  # Shell
  zsh \
  # Clean up
  && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /root

RUN curl https://mise.run | MISE_INSTALL_PATH=/bin/mise sh

# Install Linuxbrew (Homebrew for Linux)
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
  && echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.zshrc

# Install Starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes

ENV PATH="/root/.local/bin:/root/.dotfiles/bin:$PATH"

# Add plugins to mise
RUN ~/.local/bin/mise plugin add helix https://github.com/helix-editor/helix.git
RUN ~/.local/bin/mise plugin add sheldon https://github.com/rossmacarthur/sheldon.git

COPY . /root/.dotfiles

# Run dotfiles install script if it exists
RUN /root/.dotfiles/install

# Install essential tools via mise (after configs are in place)
RUN mise install


RUN pip install beets requests beets-yearfixer nginx-language-server

# Install Homebrew packages from Brewfile if it exists
RUN if [ -f "$HOME/Brewfile" ] || [ -f "/root/.dotfiles/Brewfile" ]; then \
  echo "Installing Homebrew packages..." \
  && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" \
  && brew bundle --file="/root/.dotfiles/Brewfile" || echo "Warning: Some Homebrew packages failed to install"; \
  else \
  echo "Warning: No Brewfile found, skipping brew bundle"; \
  fi

# Install Zsh plugins via Sheldon
RUN sheldon lock --update || echo "Warning: Sheldon plugin installation failed"


# Add PATH configuration to zshrc
RUN echo 'export PATH="$HOME/.dotfiles/bin:/home/linuxbrew/.linuxbrew/bin:$PATH"' >> ~/.zshrc

# Container-specific configurations
ENV SHELL=/bin/zsh
ENV TERM=xterm-256color

# Default to zsh shell
CMD ["/bin/zsh"]

# Add labels
LABEL org.opencontainers.image.title="Development Container with Dotfiles"
LABEL org.opencontainers.image.description="Ubuntu-based container with Zsh, development tools, and dotfiles setup"
LABEL org.opencontainers.image.source="https://github.com/radiosilence/dotfiles"