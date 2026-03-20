#!/usr/bin/env bash
# PostToolUse hook: remind agent to format/lint after code edits.
# Outputs additional context to the agent based on the edited file's language.

event=$(cat)
file=$(echo "$event" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

[ -z "$file" ] && exit 0

case "$file" in
  *.ex|*.exs)
    echo "Elixir file changed. Run \`mise x -- mix format\` and \`mise x -- mix credo --strict\` before committing."
    ;;
  *.rs)
    echo "Rust file changed. Run \`cargo fmt --all\` and \`cargo clippy --workspace -- -D warnings\` before committing."
    ;;
  *.ts|*.tsx|*.js|*.jsx)
    echo "JS/TS file changed. Run the project's formatter (biome/prettier) and linter (eslint) before committing."
    ;;
esac
