# scripts

Standalone commands, in zsh. This directory is on `$PATH` (see
`config.d/zsh/conf.d/dotfiles.zsh`), so everything here is a command as soon as
the repo is cloned — nothing to build.

Every script takes `--help`, `--version` and `--completions zsh|fish|bash`, all
derived from the same [zarg](../zsh-plugins/zarg/README.md) declaration it
parses with. Nothing is sourced by path: the shell exports `FPATH`, so a script
just names the functions it wants. Output helpers live in
[`lib/functions/`](lib/functions);
zarg's [`check-completions.zsh`](../zsh-plugins/zarg/check-completions.zsh)
asserts every emitted completion actually parses in its target shell, and runs
on pre-push and in CI.

---

## System

### `kill-port <port> [-n] [-s SIGNAL]`

Kills whatever holds a port. The "address already in use" fix.

```sh
kill-port 3000
kill-port -n 5432                # what would die, without killing it
kill-port -s KILL 8080           # when TERM isn't enough
kill-port 5001; task run         # the usual: reclaim, then restart
```

Matches every socket with that local port, listening or established. `-s` takes
signal *names* (`TERM KILL INT HUP QUIT USR1 USR2`) — `-s 9` is refused, and
tells you to use `KILL`.

### `unfuck-xcode [-n]`

Removes a corrupt Command Line Tools install and resets `xcode-select`, so the
GUI installer offers to reinstall. macOS only, and it will ask for sudo.

```sh
unfuck-xcode -n                  # print the two commands, run neither
unfuck-xcode
```

---

## Files

### `prune [paths...] [-s KB] [-y]`

Finds directories below a size threshold and offers to delete them. Built for
failed downloads and the empty scaffolding left behind after a cleanup.

```sh
prune                            # cwd, anything under 3 MB
prune ~/Downloads ~/Music        # several roots at once
prune -s 100 ~/Downloads         # only truly tiny dirs
MIN_SIZE=51200 prune ~/Media     # 50 MB, via the environment
prune -y ~/Downloads             # no prompt
```

Directories whose name starts with `.` are skipped entirely, subtree included —
`.git` and `.stfolder` are never candidates. Nested candidates collapse to their
topmost parent, because deleting that one takes the children anyway. Size is
what `du` reports (blocks on disk), since "how much do I get back" is the
question being asked.

### `clean-dls [paths...] [-n]`

Strips scene-release cruft: `.nfo`, `.sfv`, `.DS_Store`, `._` resource forks,
loose cover images, the four usual junk `.txt` names, and sample files.

```sh
clean-dls -n ~/Downloads/album   # always look first
clean-dls ~/Downloads/album
```

Sample matching is word-boundary aware, so `sample.mp3`, `track-sample.flac`
and `track_sample_01.flac` go, while `resampled.flac`, `SamplerV2.wav` and
`downsample.aiff` stay. Only `readme.txt`, `info.txt`, `nfo.txt` and
`file_id.diz` are treated as junk text — `lyrics.txt` survives. Afterwards it
runs `prune` over the same paths to clear directories the deletions emptied.

### `vimv [files...]`

Batch rename by editing a list in `$EDITOR`. With no arguments it takes every
regular file in the current directory.

```sh
vimv                             # everything here
vimv *.jpg                       # just these
```

Uses `git mv` for tracked files so history follows, plain `mv` otherwise, and
creates parent directories — so rewriting a line to `2024/holiday.jpg` moves the
file there. If the number of lines changes it refuses and touches nothing: a
shifted list would rename every file to its neighbour's name.

### `prune-gen`

Builds a throwaway directory tree for testing `prune` and prints its path.

```sh
prune "$(prune-gen | tail -1)"   # answer n at the prompt
```

Writes real bytes rather than sparse files, because `prune` measures blocks — a
sparse fixture reads as near-zero and stops exercising the threshold.

---

## Git

Named `git-*`, so git dispatches them as subcommands: `git sync` works too.

### `git-sync [-y]`

Fetches with `--prune`, then deletes local branches whose upstream is gone —
the litter left after PRs are merged and their remote branches deleted.

```sh
git sync                         # lists them, then asks
git-sync -y                      # no prompt
```

Branches that never had an upstream are left alone, so purely local work is
safe.

### `git-squash [parent] [-n]`

Collapses everything since the merge base into one commit, then opens `$EDITOR`
with the messages concatenated.

```sh
git squash                       # onto main
git squash develop               # onto another branch
git-squash -n                    # list what would collapse
```

Soft reset, so the tree is untouched and only history changes. Needs a force
push afterwards.

---

## Media

### `to-audio <flac|opus> [paths...] [-b KBPS] [-k] [-n]`

Converts audio in parallel via ffmpeg.

```sh
to-audio flac ~/Music/wavs       # wav/aiff/m4a → flac, lossless
to-audio opus ~/Music            # also eats flac
to-audio opus -b 192 ~/Music     # higher bitrate
to-audio flac -k ~/Music         # keep the originals
to-audio opus -n .               # list what would convert
BITRATE=96 to-audio opus .       # bitrate from the environment
```

Originals are deleted on success unless `-k`. `--bitrate` applies to opus only;
flac is lossless and ignores it. The format is a positional rather than a
subcommand because the two differed by exactly that one option.

### `embed-art [paths...]`

Embeds cover art into FLACs, taking images from each file's own directory.

```sh
embed-art ~/Music/album
```

Looks for front (`cover`/`folder`/`album`/`front`), disc (`cd`/`disc`), back
(`back`/`backcover`) and artist (`artist`/`band`), `.jpg` before `.png`. Runs
`clean-exif` over the images first, so camera metadata doesn't ride into the
FLAC. Embeds into a temp copy and only replaces the original if every picture
lands — a half-embedded FLAC never overwrites a good one.

### `extract-exif-from-flac <file.flac>`

Reports whether artwork already embedded in a FLAC still carries identifying
metadata.

```sh
extract-exif-from-flac ~/Music/album/01.flac
```

Exports each picture block and asks exiftool for GPS, serial numbers, `Artist`,
`Copyright`, `UserComment` and friends — so an answer at all *is* the finding.

### `clean-exif [paths...] [-n]`

Strips metadata from `jpg`/`jpeg`/`png`.

```sh
clean-exif -n ~/Pictures         # list first
clean-exif ~/Pictures
```

`exiftool -all=`, which removes XMP, IPTC and ICC alongside EXIF — more than
dropping the EXIF chunk gets you.

---

## Network

### `url2base64 <url> [-t TYPE] [-T SECS]`

Fetches a URL and prints it as a `data:` URL. A pipe filter: no decoration, no
trailing newline, so it drops straight into a stylesheet.

```sh
url2base64 https://example.com/icon.svg
url2base64 -t image/png https://example.com/logo.png
url2base64 -T 5 https://slow.example.com/asset.svg
url2base64 https://example.com/icon.svg | pbcopy
```

### `parallel-dl-extract <urls...>`

Downloads many archives at once with aria2c, extracts each into its own
subdirectory, and prints the temp directory it used.

```sh
dir=$(parallel-dl-extract https://ex.com/a.zip https://ex.com/b.zip | tail -1)
ls "$dir"
```

The directory is deliberately not cleaned up — it's the return value.

### `imp <urls...>`

Download, extract, and import to beets, one album per URL.

```sh
imp https://example.com/album.zip
imp https://example.com/a.zip https://example.com/b.zip
```

Each URL gets its own directory so beets sees distinct albums. `beet import` is
interactive and keeps stdin, so its prompts work normally. A failed download
skips that album and carries on.

---

## Adding one

Copy the shape of [`kill-port`](kill-port) — it is the reference:

```zsh
#!/usr/bin/env zsh
# One line on WHY this exists.
set -o pipefail

autoload +X -Uz zarg dt && dt || exit 1

zarg my-tool 'What it does'
zarg_flag -n --dry-run 'show what would happen'
zarg_arg  target 'thing to act on' required
zarg_go "$@"

dt_head my-tool
(( dry_run )) && { dt_info "would act on $target"; exit 0 }
```

Then `chmod +x`, and add the name to the zarg block of
`generate:completions` in `Taskfile.yml`. Completions, `--help` and `--version`
come for free — there is nothing else to write.
