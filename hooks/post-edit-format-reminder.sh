#!/usr/bin/env bash
# PostToolUse hook: remind agent to format/lint after source code edits.
# Language-agnostic — just detects if a source file changed and nudges.

event=$(cat)
file=$(echo "$event" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

[ -z "$file" ] && exit 0

# Skip non-source files (docs, config, etc.)
case "$file" in
  *.md|*.txt|*.json|*.yaml|*.yml|*.toml|*.lock|*.csv) exit 0 ;;
  *.gitignore|*.env*|*.conf) exit 0 ;;
esac

echo "Source file changed. Remember to run the project's formatter and linter before committing."
