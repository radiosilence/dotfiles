#!/usr/bin/env bash
# Daily-care reminders from ~/REMINDERS.md, raised inside Claude sessions.
#
#   reminders.sh hook              UserPromptSubmit: maybe inject a reminder
#   reminders.sh done <item> [n]   record n doses of an item done just now
#   reminders.sh snooze <item> <m> hold an item off for <m> minutes
#   reminders.sh status            print the reminders and today's state
#
# State is shared by every session, so a check or a "done" in one session
# counts for all of them. Haiku is asked at most once per REMINDERS_INTERVAL
# seconds across all sessions; other prompts only touch the state file.
set -euo pipefail

file="${REMINDERS_FILE:-$HOME/REMINDERS.md}"
interval="${REMINDERS_INTERVAL:-900}"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-reminders"
# A break this long resets the continuous-work clock.
gap=1200

[ -f "$file" ] || exit 0
[ -z "${REMINDERS_CHILD:-}" ] || exit 0

now=$(date +%s)
# The day rolls over at 04:00, so a late night still counts as the same day.
day_of() { date -r "$1" +%F 2>/dev/null || date -d "@$1" +%F; }
day=$(day_of $((now - 14400)))
state="$dir/$day.json"
mkdir -p "$dir"
[ -f "$state" ] || echo '{"done":[],"snoozed":{},"nags":[],"last_check":0,"active_since":0,"last_prompt":0}' >"$state"

# Re-read immediately before writing so concurrent sessions lose nothing.
update() {
  local tmp
  tmp=$(mktemp "$dir/.tmp.XXXXXX")
  jq --argjson now "$now" --arg clock "$(date +%H:%M)" "$@" "$state" >"$tmp" && mv "$tmp" "$state"
}

case "${1:-hook}" in
done)
  update --arg item "${2:?item}" --argjson n "${3:-1}" \
    '.done += [range($n) | {item: $item, at: $clock}] | del(.snoozed[$item])'
  echo "Recorded: ${3:-1}x $2 at $(date +%H:%M)"
  ;;
snooze)
  update --arg item "${2:?item}" --argjson m "${3:-30}" '.snoozed[$item] = ($now + $m * 60)'
  echo "Snoozed: $2 for ${3:-30} minutes"
  ;;
status)
  cat "$file"
  echo
  jq . "$state"
  ;;
hook)
  update --argjson gap "$gap" '
    (if $now - .last_prompt > $gap then .active_since = $now else . end)
    | .last_prompt = $now'
  last=$(jq .last_check "$state")
  [ $((now - last)) -ge "$interval" ] || exit 0
  # Claim the check before the slow call so other sessions skip this window.
  update '.last_check = $now'

  view=$(jq --argjson now "$now" '{
    done, recent_nags: .nags[-6:],
    snoozed: (.snoozed | map_values(select(. > $now) | ((. - $now) / 60 | floor | "\(.) min left"))),
    working_continuously_for_minutes: (($now - .active_since) / 60 | floor)
  }' "$state")

  prompt="You decide whether to remind someone about their daily self-care. They \
hyperfocus and forget to eat, drink water, take medication and take breaks. \
It is now $(date '+%A %H:%M'). Their reminders file and today's state follow.

Rules:
- Name only things that are due now and not yet done: a dose whose window has \
come, a daily task not done today, water if not mentioned in roughly the last \
90 minutes, a meal at a usual mealtime, a break after about 90 minutes of \
continuous work.
- Skip anything snoozed. Do not repeat a nag from the last 30 minutes unless it \
is a medication that is now overdue.
- Count doses from the done list; a 3x-daily item done once is still due later.
- If nothing is due, reply with exactly NONE.
- Otherwise reply with one short line per item, using the item's name as \
written in the file. No preamble.

<reminders>
$(cat "$file")
</reminders>

<state>
$view
</state>"

  nag=$(REMINDERS_CHILD=1 claude -p --model haiku --tools "" --setting-sources "" \
    --no-session-persistence --system-prompt "Follow the instructions exactly." \
    "$prompt" 2>/dev/null) || exit 0
  [ -n "$nag" ] && [ "$nag" != NONE ] || exit 0

  update --arg text "$nag" '.nags += [{at: $clock, text: $text}]'
  self="${CLAUDE_CONFIG_DIR:-$HOME/.claude-personal}/hooks/reminders.sh"
  jq -n --arg nag "$nag" --arg self "$self" '{hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: ("Self-care reminder from ~/REMINDERS.md, due now:\n" + $nag + "\n\n"
      + "Raise this briefly at the start of your reply, in your own voice, then carry on. "
      + "When the user says they have done one, run `bash " + $self + " done \"<item>\" <count>`, "
      + "where count is how many doses they took since last telling you (default 1). "
      + "If they defer it, run `bash " + $self + " snooze \"<item>\" <minutes>` (default 30).")}}'
  ;;
esac
