# GitHub token — evaluated once per shell session, not per subprocess
if [[ -z $GITHUB_TOKEN ]] && command -v gh >/dev/null && gh auth status &>/dev/null; then
  export GITHUB_TOKEN=$(gh auth token 2>/dev/null)
fi
