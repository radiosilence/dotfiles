# Custom Commands & Aliases

## Custom Scripts (`~/.dotfiles/bin/`)

### Port & Process

```
kill-port [OPTIONS] [PORT]
  Kill process listening on specified port
  -s, --signal <SIGNAL>  Signal to send (default: TERM)
  -n, --dry-run          Show what would be killed
```

### Git Utilities

```
git-sync [OPTIONS]
  Clean up merged branches
  -y, --yes      Delete without confirmation

git-squash [OPTIONS] [PARENT]
  Squash commits for clean PR history
  [PARENT]       Parent branch (default: main)
  -n, --dry-run  Show what would be squashed

git-trigger [OPTIONS]
  Amend and force push to trigger CI
  -n, --dry-run  Show what would be done
```

### System Maintenance

```
upd [OPTIONS]
  Update the system (brew, mise, dotfiles, rust bins)
  -v, --verbose

prune [OPTIONS] [PATHS]...
  Find and delete small directories
  -s, --min-size <KB>  Minimum size threshold [default: 3096]
  -y, --yes            Delete without confirmation

clean-dls [OPTIONS] [PATHS]...
  Clean scene release garbage (nfo, txt, etc)
  -n, --dry-run  Show what would be deleted
```

### Media & Audio

```
to-audio <COMMAND>
  Convert audio files
  flac   Convert to FLAC (lossless)
  opus   Convert to Opus (lossy, efficient)

embed-art [PATHS]...
  Embed artwork into FLAC files (looks for cover.jpg/png)

extract-exif-from-flac
  Pull EXIF/metadata from FLAC files

parallel-dl-extract [URLS]...
  Parallel download and extract using aria2c

update-ffmpeg [OPTIONS]
  Update ffmpeg build URLs in mise config
  -s, --snapshot  Use snapshot builds
  -n, --dry-run   Don't write changes
```

### File Utilities

```
vimv [FILES]...
  Batch rename files using $EDITOR
  Opens file list in editor, rename by editing, save to apply

clean-exif
  Strip EXIF data from images

url2base64
  Convert URL content to base64
```

### macOS Specific

```
install-font-macos
  Install fonts to ~/Library/Fonts

unfuck-xcode
  Reset Xcode when it's being shit

install-terminfo
  Install terminfo entries (ghostty, etc)
```

### Misc

```
regen-zsh-completions
  Regenerate zsh completions from tools

gen-diff
  Generate diff output

prune-gen
  Generate prune candidates list
```

---

## Shell Aliases

### Port & Process (`utils.zsh`)

```
whatport <port>    # lsof -i :<port> - find what's using a port
listening          # lsof -iTCP -sTCP:LISTEN -P -n - all listening ports
psg <pattern>      # procs --tree | grep - grep processes
```

### Files & Disk (`utils.zsh`)

```
recent [time]      # fd --changed-within <time> - recent files (default: 1h)
sizes [path]       # dust -d 2 - disk usage breakdown
```

### Git (`git.zsh`, `utils.zsh`)

```
g                  # git
gaa                # git add --all
gap                # git add --patch
gcmm <msg>         # git commit -m <msg>
gp                 # git push
gpl                # git pull
gco <branch>       # git checkout
gcb <branch>       # git checkout -b
glog               # git log --oneline --graph --decorate -20
gd                 # git diff
gds                # git diff --staged
```

### Package Managers

```
b / ba / bi / bt    # bun / bun add / bun install / bun test
bb                  # brew bundle
```

### Navigation

```
z <partial>        # zoxide - smart cd
..                 # cd ..
...                # cd ../..
```

### Misc

```
cat                # aliased to bat
gh                 # runs with GITHUB_TOKEN unset (uses keyring auth)
```
