---
name: release
description: Prepare a release — version bump, changelog, docs. Use when the user says "release", "cut a release", "version bump", or "/release patch|minor|major".
argument-hint: <patch|minor|major>
---

Prepare a release for the current project. **Do NOT create or push tags** — the user handles that.

`$ARGUMENTS` is the semver bump type: `patch`, `minor`, or `major`. If not provided, ask.

## 1. Discover project context

Determine the project type and find all version sources:

- **Rust**: `Cargo.toml` version field → run `cargo check` after bump to update `Cargo.lock`
- **Node/TypeScript**: `package.json` version field → run the package manager's install/lock command
- **Elixir**: `mix.exs` version field → run `mix deps.get` if needed
- **Python**: `pyproject.toml` or `setup.py` or `__version__` in source
- **Go**: version tags only (no file to bump) — note this in changelog
- **Multiple**: bump ALL version files found (monorepo)

Also check for:
- `CHANGELOG.md` or `CHANGES.md`
- `README.md` or equivalent docs
- Any version references in docs that need updating

## 2. Calculate new version

Read the current version from the primary version file. Apply the semver bump from `$ARGUMENTS`:
- `patch`: 1.2.3 → 1.2.4
- `minor`: 1.2.3 → 1.3.0
- `major`: 1.2.3 → 2.0.0

If no existing version is found, ask the user what version to start at.

## 3. Update changelog

This is the most important step. The changelog must be **thorough and useful**.

### Gather changes since last release

```bash
# Find last release tag or commit
git tag -l --sort=-v:refname | head -1
# If no tags, use first commit
git log --oneline <last-tag>..HEAD
# Get PRs merged since last release
gh pr list --state merged --base main --json number,title,author,mergedAt --limit 100
# Get issues closed since last release
gh issue list --state closed --json number,title,labels --limit 100
```

### Write the changelog entry

- Match the **existing changelog style** exactly — read the file first
- Group changes by theme (features, fixes, refactors, docs, etc.)
- Link to PRs and issues: `[#34](https://github.com/org/repo/pull/34)`
- Credit contributors: `(@username)` for external contributions
- Be specific about what changed and why — not just "updated X"
- Include breaking changes prominently if any
- Add the date: `### vX.Y.Z (YYYY-MM-DD)`

If the project doesn't have a changelog, create one following [Keep a Changelog](https://keepachangelog.com/) format.

## 4. Update docs

- Check README for version references, badges, install instructions
- Check any docs/ directory for version-specific content
- Update API docs version if applicable
- Make sure any "getting started" or install instructions reference the new version

## 5. Bump version files

- Edit the version file(s) found in step 1
- Run the appropriate lock file update command
- Run formatter on changed files

## 6. Verify

- Run the project's lint/check command (cargo clippy, eslint, mix credo, etc.)
- Run tests to make sure nothing broke
- `git diff` to review all changes

## 7. Commit and PR

Create a single commit and PR:

```
release: vX.Y.Z
```

The PR description should include the changelog entry.

**Do NOT create tags, do NOT push tags.** The user handles tag creation after merging.

## Notes

- If the project has a CI release workflow triggered by tags, mention it to the user
- If there are pre-release checks (e.g. `cargo publish --dry-run`), run them
- For work repos, follow work PR conventions (Jira linking, @claude review)
- For personal repos, follow personal conventions (changelog, no claude bot)
