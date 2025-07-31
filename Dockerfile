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

# Create user (non-root for security)
ARG USERNAME=dev
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
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Install essential tools via mise
RUN ~/.local/bin/mise install node@lts \
    && ~/.local/bin/mise install python@latest \
    && ~/.local/bin/mise use --global node@lts python@latest

# Install Sheldon (Zsh plugin manager)
RUN curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/rossmacarthur/sheldon/main/install.sh | sh

# Install Starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Install Helix editor
RUN curl -L https://github.com/helix-editor/helix/releases/latest/download/helix-24.07-x86_64-linux.tar.xz -o helix.tar.xz \
    && tar -xf helix.tar.xz \
    && sudo mv helix-24.07-x86_64-linux/hx /usr/local/bin/ \
    && sudo mkdir -p /usr/local/lib/helix \
    && sudo mv helix-24.07-x86_64-linux/runtime /usr/local/lib/helix/ \
    && rm -rf helix.tar.xz helix-24.07-x86_64-linux

# Set up dotfiles structure
RUN mkdir -p ~/.config/zsh/conf.d ~/.config/zsh/functions ~/.config/sheldon

# Copy essential dotfiles configs
COPY --chown=$USERNAME:$USERNAME config/zsh/ /home/$USERNAME/.config/zsh/
COPY --chown=$USERNAME:$USERNAME config/sheldon/ /home/$USERNAME/.config/sheldon/
COPY --chown=$USERNAME:$USERNAME config/starship/ /home/$USERNAME/.config/starship/
COPY --chown=$USERNAME:$USERNAME .zshrc /home/$USERNAME/
COPY --chown=$USERNAME:$USERNAME .zprofile /home/$USERNAME/

# Copy useful scripts (container-appropriate ones)
RUN mkdir -p ~/.local/bin
COPY --chown=$USERNAME:$USERNAME bin/kill-port /home/$USERNAME/.local/bin/
COPY --chown=$USERNAME:$USERNAME bin/bzf /home/$USERNAME/.local/bin/
COPY --chown=$USERNAME:$USERNAME bin/vimv /home/$USERNAME/.local/bin/
COPY --chown=$USERNAME:$USERNAME bin/take /home/$USERNAME/.local/bin/
COPY --chown=$USERNAME:$USERNAME bin/taketmp /home/$USERNAME/.local/bin/

# Make scripts executable
RUN chmod +x ~/.local/bin/*

# Install Zsh plugins via Sheldon
RUN ~/.local/bin/sheldon lock --update

# Set up some aliases and functions inline (container-specific)
RUN echo 'alias ll="ls -la"' >> ~/.zshrc \
    && echo 'alias la="ls -la"' >> ~/.zshrc \
    && echo 'alias ..="cd .."' >> ~/.zshrc \
    && echo 'alias ...="cd ../.."' >> ~/.zshrc

# Container-specific configurations
ENV SHELL=/bin/zsh
ENV TERM=xterm-256color

# Expose common development ports
EXPOSE 3000 3001 4000 5000 8000 8080 8443

# Default to zsh shell
CMD ["/bin/zsh"]

# Add labels
LABEL org.opencontainers.image.title="Development Container with Dotfiles"
LABEL org.opencontainers.image.description="Ubuntu-based container with Zsh, development tools, and dotfiles setup"
LABEL org.opencontainers.image.source="https://github.com/radiosilence/dotfiles"