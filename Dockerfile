# Multi-stage container with dotfiles setup
# Based on Ubuntu with essential development tools
FROM ubuntu:latest AS base

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
  btop tree \
  # Important CLI tools
  aria2 \
  beets \
  yt-dlp \
  ffmpeg \
  # Network tools
  curl wget netcat-openbsd \
  # Shell
  zsh \
  # Clean up
  && rm -rf /var/lib/apt/lists/*

# Create user jc with uid/gid 1000
ARG USERNAME=jc
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/zsh \
  && apt-get update \
  && apt-get install -y sudo \
  && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME \
  && rm -rf /var/lib/apt/lists/*

# Switch to user
USER $USERNAME
WORKDIR /home/$USERNAME

# Install mise (version manager)
RUN curl https://mise.run | sh

# Install Starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Add plugins to mise
RUN mise plugin add helix https://github.com/helix-editor/helix.git
RUN mise plugin add sheldon https://github.com/rossmacarthur/sheldon.git

# Copy dotfiles directly to final location
COPY --chown=$USERNAME:$USERNAME . /home/$USERNAME/.dotfiles

# Create SSH directory and download authorized keys
RUN mkdir -p ~/.ssh && chmod 700 ~/.ssh \
  && curl -fsSL https://github.com/radiosilence.keys > ~/.ssh/authorized_keys \
  && chmod 600 ~/.ssh/authorized_keys

# Add PATH configuration to zshrc (similar to setup-macos)
RUN echo 'export PATH="$HOME/.dotfiles/bin:$PATH"' >> ~/.zshrc

# Set PATH for this session
ENV PATH="/home/$USERNAME/.local/bin:/home/$USERNAME/.dotfiles/bin:$PATH"

# Make scripts executable and run install
RUN chmod +x /home/$USERNAME/.dotfiles/bin/* \
  && /home/$USERNAME/.dotfiles/install

# Install essential tools via mise (after configs are in place)
RUN mise install

# Run zsh once to initialize plugins and first-run setup
RUN zsh -c 'echo "Initializing zsh and plugins..."'



# Container-specific configurations
ENV SHELL=/bin/zsh
ENV TERM=xterm-256color

# Default to zsh shell
CMD ["/bin/zsh"]
