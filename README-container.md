# Dotfiles Development Container

A containerized development environment with Zsh, essential tools, and dotfiles configuration.

## Features

- **Ubuntu 24.04** base with essential development tools
- **Zsh shell** with Starship prompt and Sheldon plugin manager
- **Development tools**: Node.js, Python, mise version manager
- **CLI utilities**: ripgrep, fzf, bat, jq, htop, btop
- **Dotfiles configuration** with modular Zsh setup
- **Non-root user** for security

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Build and run
docker-compose up -d dev-shell

# Attach to shell
docker-compose exec dev-shell zsh

# Or run directly
docker-compose run --rm dev-shell
```

### Using Docker directly

```bash
# Build image
docker build -t dotfiles-dev .

# Run container
docker run -it --rm \
  -v $(pwd)/workspace:/home/dev/workspace \
  dotfiles-dev
```

## Usage on Talos

For Talos clusters, you can deploy this as a pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dev-shell
  namespace: default
spec:
  containers:
  - name: dev-shell
    image: dotfiles-dev:latest
    stdin: true
    tty: true
    workingDir: /home/dev
    ports:
    - containerPort: 3000
    - containerPort: 8080
    volumeMounts:
    - name: workspace
      mountPath: /home/dev/workspace
  volumes:
  - name: workspace
    emptyDir: {}
```

## Available Tools

- **Shell**: Zsh with Starship prompt
- **Version Manager**: mise (Node.js, Python)
- **Plugin Manager**: Sheldon
- **CLI Tools**: ripgrep, fzf, bat, jq, tree, htop, btop
- **Development**: git, curl, wget, build tools
- **Custom Scripts**: kill-port, bzf, vimv, take, taketmp

## Ports

Common development ports are exposed:
- 3000, 3001 (React, Next.js)  
- 4000, 5000 (Flask, Rails)
- 8000, 8080, 8443 (Web servers)

## Persistence

Using docker-compose, the following are persisted:
- Zsh history
- mise tool cache
- Workspace directory

## Customization

The container includes the core dotfiles setup but excludes:
- macOS-specific tools and configurations
- Audio/media processing tools
- GUI applications
- Homebrew (uses apt packages instead)

For additional tools, extend the Dockerfile or mount them at runtime.