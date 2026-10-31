---
name: pair
description: Pair-program with a partner subagent on the same model. Agree the plan with it and post it in the chat before starting, without waiting for sign-off, then show it each logical chunk of work as you go so problems are caught while they are cheap. Use when the user says "/pair", asks to pair, or wants a second pair of eyes on work as it happens.
argument-hint: "<what to work on: an issue, a feature, a bug>"
---

You drive; a partner subagent navigates. The aim is that the PR needs nothing from review because the partner already caught it. The user's whole request is the task, so read it as you would any prompt and do the work in this session.

## The partner

The partner is a fresh session on your model, not a fork, so its read isn't anchored on your context. Keep it for the whole task so it builds up context across rounds rather than starting cold.

Inside herdr-core (`HC_TERMINAL_ID` is set), run it as a terminal the user can watch and type into:

1. Start the partner: `hc run --json --bg --name pair-<repo>-<branch> --cwd "$PWD" -- env CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" claude --model <your model id> --disallowedTools "Edit,Write,NotebookEdit" -- "<brief>"`. It is a child of this terminal, so it ends when this session does. hc starts programs without your shell environment, so `env CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR"` keeps it on your Claude profile; without it Claude asks to log in. Keep the tool list comma-joined and the `--` before the brief: `--disallowedTools` is variadic and otherwise swallows the brief as tool names. `hc read` it once it starts: if `first_message.sent` is false, send the brief with `hc send`, and answer any first-run dialog with `hc send --force`.
2. It replies with `hc send $HC_TERMINAL_ID`, so put your terminal address in the brief. Replies arrive as your next input, tagged `<hc from="... pair-<repo>-<branch>">`. Talk to it with `hc send pair-<repo>-<branch>`. The repo is in the name because branch names repeat across repos, and another session's partner may already hold `pair-<branch>`.
3. `hc kill pair-<repo>-<branch>` when the PR is done.

Elsewhere, spawn it with the Agent tool as `subagent_type: "Plan"` (fresh and without edit tools) and `model` set to your own model, since an omitted model can resolve to a configured subagent default. Keep the agent ID from the result and continue it with SendMessage to that ID; load SendMessage with ToolSearch first.

Its brief tells it:
- how to reply to you;
- it is the navigator, and does not edit files, commit or run anything with side effects; it reads code and runs read-only commands to check claims;
- the task and the repo path (it loads CLAUDE.md itself, so don't restate it);
- to be direct and specific: findings with file and line, a better alternative where it has one, and silence on things that are fine. No praise, no summary of what you said;
- to push back on the approach, not just the details, when it thinks there is a simpler or more robust way;
- for every resource or side effect the change starts (an element playing, a listener, a timer, a subscription), to trace each path that should stop it, not just the one you mention, and to check that the stopping action itself succeeds: it runs with the same auth, headers and limits as the action that started the resource;
- when a change adds or reconfigures a client, server, pool or connection, to review every default it now inherits (redirects, retries, proxies, header forwarding, pooling), not only the settings you changed;
- to check every branch's failure path, and compare sibling branches: one that handles an error while its neighbour doesn't is a bug in the neighbour;
- when a component, view or function is reused somewhere new, to list every state it can now receive there (each status, an empty or finished record, a removed one) and check how it behaves for each, not only the states it was built for or the ones you mention; where the old home handled a state elsewhere (a separate row, another branch), the new home has to handle it too;
- to hold comments and code style to both CLAUDE.md files, global and repo, as well as behaviour: a comment that describes the change rather than the code, or claims more than the code does, is a finding;
- to test each assumption you flag as uncertain against the cases it would get wrong (older versions, other platforms, other callers) rather than judging it on its face;
- for each fix, its own or yours, to ask what legitimate input or caller it now refuses or treats differently, what it costs at peak (a copy, an allocation, a lock held longer), and what reads the values it changes (an average, a counter, a limit) and whether that still holds;
- that its own suggestions get no pass: once you have built one, it reviews that code as hard as anything else you send.

## Plan first

Before writing code, fetch and check what else is moving in the same area: open PRs (`gh pr list`) and recent commits on the default branch that touch the files you expect to change. Work another PR is already doing is duplicated effort and a pile of conflicts later; build on it, wait for it, or narrow the task, and say which in the plan.

Explore enough to have a real plan, then send it to the partner: the idea of what needs doing and how, the behaviour it changes, what you considered and rejected, and the parts you are least sure of. Go back and forth until you both think it's the best version, not merely an acceptable one. Usually one or two rounds; stop when replies stop changing the plan. Where you disagree and can't settle it, pick one and note the disagreement in the PR body.

Then post the agreed plan in the chat and start coding straight away, without waiting for a reply: the user reviews the PR, and the posted plan lets them stop you early if it is heading the wrong way. Make it easy to take in at a glance; the user should see in seconds whether it is heading the right way. Start with a bold one-line summary of the approach, then give each part its own short headed section and pick the form that fits each part:

- a table for options compared, or for behaviour before and after;
- a small ASCII or Mermaid diagram when the change moves data, control flow or state between components, or reshapes how they connect;
- a short code or config snippet where the shape of a new interface or signature matters more than prose about it;
- bullets for what was considered and rejected, each with its reason in a clause;
- the open disagreement, if any, and the riskiest or least certain parts, called out on their own at the end.

The plan is the idea of what needs to be done, not an inventory of the work: which files change usually isn't known until the work is under way, so don't guess at them; name a file or component only where the approach hinges on it. Leave out any section that has nothing in it, and keep each one tight: this is a map, not the PR description. If the user replies with changes, stop, take them to the partner, and carry on from the revised plan.

## Chunks as you go

After each logical chunk (a coherent change you could describe in one commit message), commit it, then send the partner the SHA and what changed and why rather than pasting the diff. A commit stays put while you carry on editing; a live `git diff` doesn't. Ask about what is uncertain: an edge case, a naming choice, whether an abstraction pays for itself. Skip trivial chunks such as renames, config tweaks and docs-only edits; batch small ones together.

Keep working while it reads unless the next chunk depends on its answer. Fold its feedback in before the PR, fix what's right, and tell it briefly why you didn't take the rest so it calibrates.

Review runs both ways. A fix the partner suggests is a proposal, not a finding: before building it, check it as the partner would check your code: what legitimate traffic or caller it now refuses, what it costs at peak, what reads the values it changes, and whether its trigger is narrower than the problem it names. Push back on the parts that fail, and send the built version back for its review like any other chunk.

Before opening the PR, merge the default branch in, then give the partner the whole branch diff for one last pass and fold that in. Then push and open the PR as usual.

## While this skill is being tuned

After the PR is open and the partner's final pass is in, run `/code-review medium` on it; the level is pinned so runs are comparable. Triage each finding in the session: fix it, or note why not in your report. Report to the user, in a few lines, which valid findings the partner missed and what in this skill's prompt would have caught them. False positives aren't misses.
