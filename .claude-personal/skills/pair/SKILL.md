---
name: pair
description: Pair-program with a partner subagent on the same model. Agree the plan with it before starting, then show it each logical chunk of work as you go so problems are caught while they are cheap. Use when the user says "/pair", asks to pair, or wants a second pair of eyes on work as it happens.
argument-hint: "<what to work on: an issue, a feature, a bug>"
---

You drive; a partner subagent navigates. The aim is that the PR needs nothing from review because the partner already caught it. The user's whole request is the task, so read it as you would any prompt and do the work in this session.

## The partner

Spawn one partner with the Agent tool: no `model` (it inherits yours), no `subagent_type` (a fresh general-purpose agent, not a fork, so its read isn't anchored on your context), named `pair`. Keep it for the whole task and talk to it with SendMessage so it builds up context across rounds rather than starting cold.

Its brief tells it:
- it is the navigator, and does not edit files, commit or run anything with side effects; it reads code and runs read-only commands to check claims;
- the task, the repo path and the user's CLAUDE.md rules that matter for it;
- to be direct and specific: findings with file and line, a better alternative where it has one, and silence on things that are fine. No praise, no summary of what you said;
- to push back on the approach, not just the details, when it thinks there is a simpler or more robust way.

## Plan first

Before writing code, explore enough to have a real plan, then send it to the partner: the approach, the files and behaviour it touches, what you considered and rejected, and the parts you are least sure of. Go back and forth until you both think it's the best version, not merely an acceptable one. Usually one or two rounds; stop when replies stop changing the plan. Where you disagree and can't settle it, say so in the plan you show the user.

Then present the agreed plan to the user: concise, covering the approach, what changes, and any open disagreement. Wait for their sign-off before writing code, and take their changes back to the partner if they reshape the plan.

## Chunks as you go

After each logical chunk (a coherent change you could describe in one commit message), send the partner what changed and why, and point it at the diff (`git diff`, or the commit) rather than pasting it. Ask about what is uncertain: an edge case, a naming choice, whether an abstraction pays for itself. Skip trivial chunks such as renames, config tweaks and docs-only edits; batch small ones together.

Keep working while it reads unless the next chunk depends on its answer. Fold its feedback in before the PR, fix what's right, and tell it briefly why you didn't take the rest so it calibrates.

Push and open the PR as usual. Before reporting done, give the partner the final diff for one last pass.

## While this skill is being tuned

After the PR is open, run `/code-review --comment` on it. Every finding is something the pairing missed. Report to the user, in a few lines, what the review caught that the partner didn't and what in this skill's prompt would have caught it.
