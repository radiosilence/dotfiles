#!/usr/bin/env bash
# Machine watchdog and neighbour list shared by every guvnor on this machine.
#
#   watchdog.sh           run in the background; exits with the alert as its
#                         output when the machine is short of memory or disk,
#                         which wakes the guvnor that started it. Restart it
#                         after acting.
#   watchdog.sh status    one line of current readings.
#   watchdog.sh books     CPU and memory summed per project, from each
#                         process's working directory.
#   watchdog.sh sign <t>  set your one-line sign (who, remit, crew, in flight,
#                         holding). Needs GUV and a running watchdog.
#   watchdog.sh guvs      every live guvnor and their sign.
#
# GUV="<ListAgents name> <project>" registers the running instance. Its sign
# disappears when it exits, so the list only ever shows guvnors still running.
#
# Every instance waits on one alert log, but only the holder of the lock
# samples, so several guvnors get the same alert once. A breach must hold for
# two samples in a row, and the same kind alerts at most once per COOLDOWN, so
# a spike or a machine that stays busy does not keep waking everyone. Load is
# reported but never alerts: on macOS it counts threads waiting on disk, and a
# busy machine is not a dying one.
set -uo pipefail

INTERVAL=${INTERVAL:-60}
MEM_FREE_MIN=${MEM_FREE_MIN:-10}    # percent free, from memory_pressure
DISK_FREE_MIN=${DISK_FREE_MIN:-50}  # GB free on the data volume
COOLDOWN=${COOLDOWN:-900}           # seconds before the same breach alerts again

dir=${XDG_CACHE_HOME:-$HOME/.cache}/guv
lock=$dir/watchdog.lock
alerts=$dir/alerts
registry=$dir/guvs
mkdir -p "$dir" "$registry"
touch "$alerts"

sample() {
  load=$(sysctl -n vm.loadavg | awk '{print $3}')
  mem=$(memory_pressure -Q 2>/dev/null | awk '/percentage/{print $NF+0}')
  disk=$(/bin/df -g /System/Volumes/Data | awk 'NR==2{print $4}')
  swap=$(sysctl -n vm.swapusage | awk '{print $6}')
}

breaches() {
  local out=""
  (( mem < MEM_FREE_MIN )) && out+="memory ${mem}% free, swap ${swap} used; "
  (( disk < DISK_FREE_MIN )) && out+="disk ${disk}G free; "
  printf '%s' "${out%; }"
}

hold_lock() {
  [[ $(cat "$lock/pid" 2>/dev/null) == "$$" ]] && return 0
  if mkdir "$lock" 2>/dev/null; then
    echo $$ > "$lock/pid"
    return 0
  fi
  local holder
  holder=$(cat "$lock/pid" 2>/dev/null)
  [[ -n $holder ]] && ! kill -0 "$holder" 2>/dev/null && rm -rf "$lock"
  return 1
}

live_entries() {
  local f
  for f in "$registry"/*; do
    [[ -f $f ]] || continue
    if kill -0 "${f##*/}" 2>/dev/null; then echo "$f"; else rm -f "$f"; fi
  done
}

project_of() {
  local cwd=$1
  case $cwd in
    */worktrees/*) cwd=${cwd#*/worktrees/}; echo "${cwd%%/*}" ;;
    "$HOME"/workspace/*/*) cwd=${cwd#"$HOME"/workspace/*/}; echo "${cwd%%/*}" ;;
    "$HOME"/.dotfiles*) echo dotfiles ;;
    *) echo other ;;
  esac
}

books() {
  local pid cpu rss cwd
  ps -Ao pid=,pcpu=,rss= | awk '$2 > 0.5' | while read -r pid cpu rss; do
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
    printf '%s %s %s\n' "$(project_of "${cwd:-/}")" "$cpu" "$rss"
  done | awk '{c[$1]+=$2; m[$1]+=$3} END {for (p in c) printf "%6.0f%% %7.0fM  %s\n", c[p], m[p]/1024, p}' \
    | sort -rn
}

sign() {
  local f
  for f in $(live_entries); do
    if [[ $(head -1 "$f") == "${GUV:?set GUV as for the watchdog}" ]]; then
      printf '%s\n%s\n' "$GUV" "$1" > "$f"
      return 0
    fi
  done
  echo "no running watchdog for '$GUV'; start it first" >&2
  return 1
}

case ${1:-} in
  books) books; exit 0 ;;
  sign) sign "${2:?usage: watchdog.sh sign <text>}"; exit ;;
  guvs)
    for f in $(live_entries); do
      printf '%s: %s\n' "$(head -1 "$f" | sed 's/ [^ ]*$//')" "$(sed -n 2p "$f")"
    done
    exit 0 ;;
  ''|status) ;;
  *) echo "unknown command '$1'; use status, books, sign or guvs, or no argument to watch" >&2; exit 2 ;;
esac

sample
status="load ${load}, memory ${mem}% free, swap ${swap} used, disk ${disk}G free"
if [[ ${1:-} == status ]]; then
  echo "$status"
  exit 0
fi

trap '[[ $(cat "$lock/pid" 2>/dev/null) == "$$" ]] && rm -rf "$lock"; rm -f "$registry/$$"' EXIT
[[ -n ${GUV:-} ]] && printf '%s\n%s\n' "$GUV" "(no sign yet)" > "$registry/$$"
echo "watchdog: $status"
seen=$(wc -l < "$alerts")
prev=""

while sleep "$INTERVAL"; do
  if hold_lock; then
    sample
    now=$(breaches)
    if [[ -n $now && -n $prev ]]; then
      kinds=$(sed -E 's/ [^;]*//g' <<< "$now")
      last=$(grep -F " $kinds " "$alerts" | tail -1 | cut -d' ' -f1)
      if (( $(date +%s) - ${last:-0} >= COOLDOWN )); then
        echo "$(date +%s) $kinds $(date '+%H:%M') $now" >> "$alerts"
      fi
      now=""
    fi
    prev=$now
  fi
  if (( $(wc -l < "$alerts") > seen )); then
    echo "watchdog: $(tail -1 "$alerts" | cut -d' ' -f3-)"
    exit 1
  fi
done
