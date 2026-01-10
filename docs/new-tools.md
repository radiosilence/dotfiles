# New CLI Tools Cheatsheet

Quick reference for the shiny new toys.

## delta - Better Git Diffs

Git pager with syntax highlighting, line numbers, and side-by-side view.

```bash
# Already configured as git pager once you add to gitconfig:
# [core]
#   pager = delta
# [interactive]
#   diffFilter = delta --color-only

# Side-by-side diff
git diff --side-by-side
delta --side-by-side file1 file2

# Diff two files directly
delta file1 file2
```

**Why:** Makes git diffs actually readable. Syntax highlighting per language, word-level diff highlighting, line numbers.

---

## dust - Better du

Visual disk usage analyzer. Shows what's eating your disk.

```bash
# Current directory
dust

# Specific path
dust ~/workspace

# Limit depth
dust -d 2

# Show hidden files
dust -H

# Reverse sort (smallest first)
dust -r

# Only show N items
dust -n 10
```

**Why:** Actually shows you a visual bar chart of what's hogging space instead of a wall of numbers.

---

## procs - Better ps

Modern process viewer with tree view, search, and better defaults.

```bash
# All processes (default)
procs

# Tree view
procs --tree

# Watch mode (like top but better)
procs --watch

# Search by name
procs zsh

# Search by PID
procs --pid 1234

# Sort by memory
procs --sortd mem

# Sort by CPU
procs --sortd cpu
```

**Why:** Color-coded, human-readable output. Tree view actually works. Search is fast.

---

## tokei - Code Stats

Fast code statistics (lines, blanks, comments) per language.

```bash
# Current directory
tokei

# Specific path
tokei src/

# Specific languages only
tokei -t rust,go

# Exclude directories
tokei -e node_modules -e target

# Sort by lines
tokei -s lines

# Sort by code (non-comment, non-blank)
tokei -s code

# Output as JSON
tokei -o json
```

**Why:** Blazingly fast. Recognizes tons of languages. Great for "how big is this codebase" questions.

---

## xh - Modern HTTP Client

HTTPie-like but in Rust. Cleaner output, faster.

```bash
# GET request
xh httpbin.org/get

# POST with JSON body
xh POST httpbin.org/post name=james role=dev

# POST with raw JSON
xh POST api.example.com/users --raw '{"name": "james"}'

# Custom headers
xh example.com Authorization:"Bearer token123"

# Form data
xh --form POST example.com/upload file@./data.txt

# Download file
xh --download example.com/file.zip

# Only show headers
xh --headers example.com

# Verbose (show request too)
xh -v example.com

# Don't follow redirects
xh --no-follow example.com
```

**Why:** Colorized output, sensible defaults, doesn't need Python.

---

## oha - HTTP Load Testing

Replaced `wrk`. HTTP load generator with nice TUI.

```bash
# Basic load test (200 req, 50 concurrent)
oha -n 200 -c 50 http://localhost:3000

# Sustained load for 30 seconds
oha -z 30s -c 100 http://localhost:3000

# POST with body
oha -m POST -d '{"test": true}' -T application/json http://localhost:3000/api

# Custom headers
oha -H "Authorization: Bearer xxx" http://localhost:3000

# HTTP/2
oha --http2 https://example.com

# Disable TUI (CI mode)
oha --no-tui -n 1000 http://localhost:3000

# Output JSON results
oha -j -n 1000 http://localhost:3000 > results.json
```

**Why:** Real-time TUI showing latency distribution. HTTP/2 support. Cleaner output than wrk.
