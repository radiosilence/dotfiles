# gh-board

A Herdr app mod for working across many GitHub repositories without the web UI. `cmd-shift-g` opens it (the `popup-gh` mod), in a space of its own called GitHub.

## What it does

The board lists the open PRs of every repository added to it (type `owner/repo` in its box) with their CI, mergeability, review and auto-merge state, and acts on them in place: merge, auto-merge, update branch, rerun failed checks. Clicking a PR shows it in a preview pane beside the board; **Pin** keeps one in a pane of its own. **Actions** under a repository shows its runs, release runs, releases and dispatchable workflows.

Behaviour that is not obvious from the screen:

- Merging takes two clicks on the same head commit within four seconds, and the mutation names that commit. A push that lands between looking and clicking makes the merge fail instead of merging code nobody saw.
- **Merge** is offered when only checks that are not required are failing (GitHub's `UNSTABLE`), since anyone with write access may merge then. **Admin merge** waits until GitHub has computed whether the PR can merge at all.
- **Fix** opens the PR's worktree as a Herdr space through `wtpr-space` (`zsh-plugins/wt-herdr`) and starts Claude there with the conflicts, the failing checks and the commands to read their logs. PRs from forks are excluded: `wtpr` can resolve a fork's branch to the wrong checkout (#117).
- Rerun only reaches GitHub Actions runs. Failing checks from other apps and commit statuses are reported as not rerun rather than skipped silently.
- GitHub PR and issue links in descriptions and comments open in the preview pane rather than the browser.
- **Needs you** is your PRs that are failing, conflicting, behind, have changes requested or are ready to merge, plus anyone's PR whose review is requested from you. Bots' PRs never appear in it unless your review is requested.
- Dispatching a workflow uses its inputs' defaults; GitHub's refusal is shown when an input is required.

## How it talks to GitHub

Requests go straight to the GitHub API with `fetch`, using the token from `gh auth token`, so there is no separate login. Reading and acting on PRs uses GraphQL; only Actions runs, reruns, cancellation and dispatch use REST, because GraphQL does not offer them.

The 5,000-point hourly GraphQL budget is shared with every other `gh` call on the same token, so polling is sized to it:

- The board fetches all repositories in aliased queries of eight, which cost about one point per few repositories. Per-check detail is not polled; it is read when a PR is opened or acted on.
- Each repository is refreshed every 60 seconds while the board is shown and every 5 minutes otherwise. A repository with running checks, a mergeability GitHub has not yet computed, an auto-merge about to happen, or an action just taken is refreshed every 15 seconds. Pending states older than 45 minutes do not count, since a required status that never reports or a run waiting for approval would otherwise keep a repository on the fast schedule indefinitely.
- A push from a local checkout moves its remote refs, which the board watches; that repository goes on the fast schedule for two minutes. The checkout is found as wt-core finds it (`~/workspace/<owner>/<repo>`, then `~/workspace/*/<repo>`, then `~/.<repo>`) and confirmed by its remote URL.
- Below 1,000 remaining points every interval is four times longer; a rate-limit error stops polling until the limit resets.
- A failed request leaves the last good data on screen, marked stale, rather than clearing it.

GitHub has no push API a desktop mod can listen to without a public endpoint. Webhook delivery would need a relay (a GitHub App and a small forwarding service), which is left for later.

## Limits

- Inline review threads are not shown yet; review summaries and comments are.
- Issues open on GitHub; an issue view is planned.
- At most 30 open PRs per repository are listed, most recently updated first.
- Workflow inputs cannot be entered; dispatch uses their defaults.
- Release runs are found by `event=release`, by a release tag push among the 20 most recent runs, or by a workflow path naming release or publish. GitHub cannot filter runs by tag push, so older tag-push runs are missed.

## Development

The data handling in `gh.js` is pure and tested with `node --test config.d/herdr-app/mods/gh-board`. `herdr-app check ~/.config/herdr-app/mods/gh-board` loads the mod once. The repository list is kept in the app's shared state under `gh-board.repos`.
