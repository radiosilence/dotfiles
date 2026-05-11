
# Socket Firewall wraps for non-JS package managers ni doesn't touch.
# sfw also supports: yarn, pnpm, bun, pip, uv, cargo (ni handles npm-family).
if command -v sfw >/dev/null; then
  alias uv='sfw uv'
  alias cargo='sfw cargo'
fi
