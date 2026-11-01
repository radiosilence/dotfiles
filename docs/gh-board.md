# gh-board

A Herdr app mod for working across many GitHub repositories without the web UI. `cmd-shift-g` opens it (the `popup-gh` mod), in a space of its own called GitHub.

## What it does

The board lists every repository added to it, each with its default branch's latest Actions runs, its latest release, and its open PRs. Each PR row shows its CI state, what stands between it and merging (conflicts, behind, blocked, ready), review state and auto-merge, with buttons for what can be done next:

- **Merge / Admin merge**: two clicks on the same head commit within four seconds. Admin merge appears only when GitHub reports `viewerCanMergeAsAdmin`.
- **Auto / Auto off**: enables or disables auto-merge with the repository's preferred method (squash, then merge, then rebase).
- **Update**: merges the base branch into a PR that is behind.
- **Rerun**: reruns the failed jobs of every Actions run behind the PR's failing checks. Checks from other apps and commit statuses cannot be rerun, and are reported rather than skipped.
- **Fix**: opens the PR's worktree as a Herdr space through `wtpr-space` (see `zsh-plugins/wt-herdr`) and starts Claude there with the conflicts, failing checks and their `gh run view --log-failed` commands. PRs from forks are excluded until #117 is fixed.

Clicking a row shows the PR in a preview pane beside the board: description, checks, conversation and a comment box, with the same actions. **Pin** splits off a pane that keeps that PR while the preview follows later clicks. GitHub PR and issue links in descriptions and comments open in the preview rather than the browser.

**Actions** under a repository shows its recent runs (with Cancel, Rerun, Rerun failed), runs from releases separately, its releases, and a button for each workflow with a `workflow_dispatch` trigger. Workflows with inputs are dispatched with their defaults; GitHub's refusal is shown when an input is required.

The filters are **All**, **Needs you** (your PRs that are failing, conflicting, behind, have changes requested or are ready to merge, and anyone's PR whose review is requested from you) and **Mine**. The text box filters rows; an `owner/repo` (or its URL) followed by Enter adds a repository, and focusing it lists your recently pushed repositories.

## How it talks to GitHub

Requests go straight to the GitHub API with `fetch`, using the token from `gh auth token`, so there is no separate login. Reading and acting on PRs uses GraphQL; only Actions runs, reruns, cancellation and dispatch use REST, because GraphQL does not offer them.

The 5,000-point hourly GraphQL budget is shared with every other `gh` call on the same token, so polling is sized to it:

- The board fetches all repositories in aliased queries of eight, which cost about one point per few repositories. Per-check detail is not polled; it is read when a PR is opened or acted on.
- Each repository is refreshed every 60 seconds while the board is shown and every 5 minutes otherwise. A repository with running checks, a mergeability GitHub has not yet computed, an auto-merge about to happen, or an action just taken is refreshed every 15 seconds. Pending states older than 45 minutes do not count, since a required status that never reports or a run waiting for approval would otherwise keep a repository on the fast schedule indefinitely.
- A push from a local checkout under `~/workspace/<owner>/<repo>` moves its remote refs, which the board watches; that repository goes on the fast schedule for two minutes.
- Below 1,000 remaining points every interval is four times longer; a rate-limit error stops polling until the limit resets.
- A failed request leaves the last good data on screen, marked stale, rather than clearing it.

GitHub has no push API a desktop mod can listen to without a public endpoint. Webhook delivery would need a relay (a GitHub App and a small forwarding service), which is left for later.

## Limits

- Inline review threads are not shown yet; review summaries and comments are.
- Issues open on GitHub; an issue view is planned.
- At most 30 open PRs per repository are listed, most recently updated first.
- Workflow inputs cannot be entered; dispatch uses their defaults.

## Development

The data handling in `gh.js` is pure and tested with `node --test config.d/herdr-app/mods/gh-board`. `herdr-app check ~/.config/herdr-app/mods/gh-board` loads the mod once. The repository list is kept in the app's shared state under `gh-board.repos`.
