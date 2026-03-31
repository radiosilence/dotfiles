# devbox

Isolated dev containers for supply chain attack mitigation. Base image is built from this dotfiles repo via `task converge`, so the container environment stays in lockstep with your host config (minus macOS-specific stuff).

See [radiosilence/dotfiles#48](https://github.com/radiosilence/dotfiles/issues/48) for the full design doc.

## Usage

```bash
dev b2c-spa                          # start or reattach (tmux session)
dev b2c-spa -p 3000                  # with port forward (3000:3000)
dev b2c-spa -p 3000 -p 5432         # multiple ports
dev b2c-spa -r git@github.com:o/r   # auto-clone into volume on first run

dev-stop b2c-spa                     # stop container, keep volume
dev-nuke b2c-spa                     # stop + delete volume + all data
dev-update                           # pull latest image, stop running boxes
dev-ls                               # list running devboxes
dev-exec b2c-spa npm test            # run command in container
dev-build                            # build image locally
```

Re-running `dev <name>` after a stop recreates the container from the latest image. The volume (your code) is preserved.

## Injected Environment Variables

All secrets are fetched at **container start time** from 1Password (with `gh auth token` fallback). Nothing is baked into the image.

| Variable | Source | Purpose |
|----------|--------|---------|
| `GITHUB_TOKEN` | `op://Dev/gh-devbox-pat/credential` or `gh auth token` | Git operations, mise downloads, GitHub API (rate limits) |
| `NPM_TOKEN` | `op://Dev/npm-token/credential` | Private npm registry auth (referenced in `.npmrc` as `${NPM_TOKEN}`) |
| `ANTHROPIC_API_KEY` | `op://Dev/anthropic-key/credential` | Claude Code inside the container |
| `HEX_API_KEY` | `op://Dev/hex-key/credential` | Hex.pm private packages (Elixir) |
| `SSH_AUTH_SOCK` | 1Password SSH agent socket (mounted read-only) | Git push/pull, SSH — triggers passkey prompt on host |
| `DEVBOX_REPO` | `-r` flag | Auto-clone URL for first run (entrypoint checks if `/workspace` is empty) |

### 1Password Setup

Create these items in your 1Password vault (vault name: `Dev`):

- **`gh-devbox-pat`** — Fine-grained GitHub PAT with "Public Repositories (read-only)" permission. Zero write access. Add more perms later if needed for PRs.
- **`npm-token`** — Granular npm automation token, read-only scope.
- **`anthropic-key`** — Anthropic API key.
- **`hex-key`** — Hex.pm API key (if using private packages).

If an item doesn't exist, `op read` fails silently and the env var is not set.

## SSH Agent Forwarding

The 1Password SSH agent socket is mounted read-only into the container. Every `git push`, `ssh` connection etc. triggers a passkey/Touch ID prompt on the host machine. The container never sees a private key.

## Safe npm Defaults

The container ships with a hardened `~/.npmrc`:

```ini
ignore-scripts=true    # block postinstall scripts (primary supply chain vector)
git=/bin/false         # block git deps entirely (PackageGate CVE-2025-69263 mitigation)
audit-level=moderate
package-lock=true
save-exact=true
engine-strict=true
```

To allow lifecycle scripts for a specific project (inside the container only):
```ini
# project-level .npmrc
ignore-scripts=false
```

## Database / Service Containers

The devbox does **not** have Docker socket access (intentional — socket access = container escape vector). To run databases:

**Run services on the host, connect from devbox:**

```bash
# On host
docker run -d --name postgres -p 5432:5432 -e POSTGRES_PASSWORD=dev postgres:16

# In devbox (OrbStack)
psql -h host.docker.internal -U postgres

# Or with Docker Desktop
psql -h host.docker.internal -U postgres
```

`host.docker.internal` resolves to the host from inside any container. Your devbox can reach any port the host exposes. No socket mounting needed.

For project docker-compose files, run them on the host:
```bash
# On host
cd ~/workspace/my-project && docker compose up -d

# Services are reachable from devbox via host.docker.internal:<port>
# Or via container name if on the same Docker network
```

## Updates

```bash
dev-update    # pulls latest ghcr.io/radiosilence/devbox:latest, stops running containers
dev b2c-spa   # recreates container from new image, volume preserved
```

The image is rebuilt by GHA on every push to `containers/**` on main. Language toolchains, dotfiles config, tmux plugins, zsh completions — all updated automatically.

## Image Contents

Built via `task converge` from this dotfiles repo on Ubuntu 24.04:

- **Languages**: Node.js (LTS), Bun, Erlang 27, Elixir 1.18, Rust (stable), Go (latest)
- **Package managers**: npm, pnpm (via corepack), cargo, mix/hex, go modules
- **Tools**: mise, go-task, gh CLI, tmux, zsh, sheldon, cargo-audit, cargo-deny, govulncheck
- **Config**: dotfiles symlinks, tmux plugins, zsh completions, starship prompt

## Security Model

- Base image has **zero credentials** — all secrets injected at runtime via env vars
- `--cap-drop=ALL --security-opt=no-new-privileges` — minimal Linux capabilities
- `--memory=8g --cpus=4` — resource limits prevent crypto mining / DoS
- SSH keys never enter the container — 1Password agent socket handles signing
- npm `ignore-scripts=true` + `git=/bin/false` blocks primary supply chain vectors
- Named volumes (not host bind mounts) for workspace isolation
