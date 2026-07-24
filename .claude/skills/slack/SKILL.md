---
name: slack
description: Read and post to Slack from OMP (or any harness without a Slack connector) by shelling out to the `claude` CLI, which has the managed Slack MCP authed and connected. ALWAYS trigger this skill whenever a Slack URL appears anywhere in the chat -- any `slack.com/archives/...` link (e.g. `shedul.slack.com/archives/C.../p...`), a `slack://` link, or a message/thread/channel permalink -- even if the user only pastes the link with no explicit instruction. Also trigger when the user wants to read a Slack thread/channel, post or reply to a message, add a reaction, or search Slack, and no native Slack tool is present in the current session.
allowed-tools: Bash
---

# slack

OMP has no Slack connector. **Claude Code does** -- its `claude.ai Slack` managed MCP is authed and `✔ Connected`. So borrow it: shell out to the `claude` CLI in headless mode and let it drive the Slack tools. Same trick works for any managed connector Code has (Gmail, Notion, Calendar, Drive, Atlassian, Figma...).

## Model split: brain reads & writes, arm carries

This skill runs in **the current foreground model** (Opus, or whatever the session is on) -- that's deliberate, hence no `model:` in the frontmatter. Keep the split clean:

- **The FG model (brain) does all comprehension and composition.** Understanding the thread, deciding whether/what to reply, drafting the exact message text -- that's judgement, it stays here. Never delegate the thinking.
- **`claude -p --model haiku` (arm) is dumb transport only.** It just carries a fully-formed instruction to the Slack MCP and pipes the result back: "read thread X verbatim", "post this exact text to thread Y". It never decides content.

So the brain reads the raw thread (via a haiku shell-out that returns it verbatim -- no summarizing), comprehends it here in full context, writes the reply word-for-word, then hands haiku a "post exactly this" command. Haiku is the wire, not the writer.

## When a Slack URL shows up: fetch context FIRST, unprompted

A pasted Slack link is a request for context, even with no instruction attached. The moment one appears in the chat, **before replying to the user or doing anything else**:

1. Parse `CHANNEL_ID` and the ts from the URL (see "Parsing a Slack permalink" below).
2. **Read it immediately** -- `slack_read_thread` for a `p...`/`thread_ts` link, `slack_read_channel` for a bare channel link. Pull the full thread verbatim, not a snippet.
3. If the thread references another thread, channel, user, or file, follow it (`slack_read_thread` / `slack_read_user_profile` / `slack_read_file`) until you actually understand what's being discussed.
4. Only then respond to the user, grounded in what the thread actually says.

Do **not** ask "want me to read it?" -- just read it and report what's there. Reading is free and non-destructive; posting is the only thing that needs care. Never post, react, or reply back into Slack off a pasted link unless the user explicitly asks -- default to read-only.

## Do it quietly -- no narration

This is plumbing. **Say nothing while you work.** No "Slack link dropped, gotta pull that thread", no "plan's trivial here", no "fetching now", no announcing the shell-out. Just silently run the read and go straight to the answer.

- Zero preamble before the tool call. The tool call itself is the only signal the user needs that something's happening.
- No meta-commentary about what the skill is, what you're about to do, or how simple/trivial the task is.
- After fetching: lead with the **answer to what the user actually asked** (e.g. "do we need lots?" -> answer it), grounded in the thread. Not "here's what the thread says" -- just the answer, with thread detail only as needed to support it.
- The FG model still does the thinking; it just does it silently. Think, fetch, answer. No live diary.

## The one-liner

```bash
claude -p --model haiku --dangerously-skip-permissions "<prompt telling it which slack_* tool to use and with what args>"
```

- `-p` -- headless: prints the result and exits, so it behaves as a plain CLI tool.
- `--model haiku` -- cheap; Haiku drives the MCP calls fine. Bump to `sonnet` only if it flails.
- `--dangerously-skip-permissions` -- no interactive tool-approval prompts (required for non-interactive use).
- The flag is **`--model`, not `-m`** (`-m` errors with `unknown option`).

Confirm the connector is live first if unsure: `claude mcp list` -> look for `claude.ai Slack ... ✔ Connected`.

## Slack tool names (namespaced `mcp__claude_ai_Slack__*`)

You don't pass these directly -- you name them in the prompt so the sub-agent picks the right one. Verified available:

- `slack_read_thread` -- read a thread (channel id + thread_ts)
- `slack_read_channel` -- read recent channel messages
- `slack_send_message` -- post a message; pass `thread_ts` to reply in-thread
- `slack_add_reaction` / `slack_get_reactions`
- `slack_search_public` / `slack_search_public_and_private` / `slack_search_channels` / `slack_search_users`
- `slack_read_user_profile` / `slack_list_channel_members`
- `slack_schedule_message`, `slack_send_message_draft`
- `slack_create_canvas` / `slack_read_canvas` / `slack_update_canvas` / `slack_read_file` / `slack_create_conversation`

## Parsing a Slack permalink

`https://<workspace>.slack.com/archives/<CHANNEL_ID>/p<TS>`

- `CHANNEL_ID` = the path segment after `/archives/` (e.g. `C08963VPK1A`).
- Message ts = the `p` number with a `.` inserted before the **last 6 digits**: `p1784906364468409` -> `1784906364.468409`.
- A reply's thread_ts is the **parent** message's ts (in the URL as `?thread_ts=...`).

## Recipes

Read a thread verbatim:
```bash
claude -p --model haiku --dangerously-skip-permissions \
  "Use slack_read_thread to read channel C08963VPK1A thread_ts 1784906364.468409. Print every message verbatim with author and text. Do not summarize."
```

Reply in-thread (single-quote the outer arg; embedded literal text goes in double quotes):
```bash
claude -p --model haiku --dangerously-skip-permissions \
  'Use slack_send_message to post a threaded reply in channel C08963VPK1A to thread_ts 1784906364.468409. Send exactly this text: "your message here". Then report the resulting message ts and permalink.'
```

Search:
```bash
claude -p --model haiku --dangerously-skip-permissions \
  "Use slack_search_public to find messages matching 'deploy freeze' in the last week. List channel, author, ts, text."
```

## Gotchas

- **Posts as the authed user**, not a bot -- messages appear from whoever owns the Code CLI's Slack auth, tagged *Sent using @Claude*. Don't post anything you wouldn't say under that name.
- **Always read before you write.** Never post a reply until you've read the thread and know what you're responding to.
- **Verify the write landed**: re-run `slack_read_thread` and confirm your message is present before declaring done.
- Quoting: wrap the prompt in single quotes and put the literal message body in double quotes so shell expansion doesn't mangle it. Escape apostrophes in the body as `'"'"'`.
- Cold MCP start makes the first call take ~10-15s. Give it a generous timeout.
