#!/usr/bin/env bash
# PostToolUse hook: remind agent to format/lint after source code edits.

event=$(cat)
file=$(echo "$event" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

[ -z "$file" ] && exit 0

# Skip non-source files
case "$file" in
  *.md|*.txt|*.json|*.yaml|*.yml|*.toml|*.lock|*.csv) exit 0 ;;
  *.gitignore|*.gitattributes|*.editorconfig|*.env*|*.conf) exit 0 ;;
esac

printf "  \033[33m\033[0m %s\n" "Source file changed — run formatter/linter before committing."
