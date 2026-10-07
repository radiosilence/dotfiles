#!/usr/bin/env bash
# Machine watchdog shared by every guvnor on this machine.
#
#   watchdog.sh          run in the background; exits with the alert as its
#                        output when the machine needs action, which wakes the
#                        guvnor that started it. Restart it after acting.
#   watchdog.sh status   print one line of current readings and exit.
#   watchdog.sh guvs     list the guvnors whose watchdogs are running.
#   watchdog.sh top      the heaviest processes with their working directories,
#                        to tell whose crew is loading the machine.
#   watchdog.sh books    CPU and memory summed per project, from each
#                        process's working directory.
#   watchdog.sh post <t> pin a notice on the shared board, signed with $GUV.
#   watchdog.sh board    the board's recent notices.
#   watchdog.sh ask <g>  record that you are asking guvnor <g> to shed load.
#                        Fails, naming the asker, if someone already asked <g>
#                        within COOLDOWN, so a guvnor is not asked by everyone.
#
# GUV="<ListAgents name> <project>" registers the running instance, so other
# guvnors can find this one with `watchdog.sh guvs`. Entries die with it.
#
# Every running instance waits on one alert log, but only one of them (the
# holder of the lock) samples, so several guvnors see the same alert once
# rather than each raising its own. A threshold must hold for two samples in a
# row, so a single spike does not wake anyone, and the same kind of breach
# alerts at most once per COOLDOWN, so a machine that stays busy does not keep
# waking every guvnor. When the sampler exits, another
# instance takes the lock on its next tick.
set -uo pipefail

INTERVAL=${INTERVAL:-60}
LOAD_PER_CORE=${LOAD_PER_CORE:-4}   # 5-minute load average per core
MEM_FREE_MIN=${MEM_FREE_MIN:-10}    # percent free, from memory_pressure
DISK_FREE_MIN=${DISK_FREE_MIN:-50}  # GB free on the data volume
COOLDOWN=${COOLDOWN:-900}           # seconds before the same breach alerts again

dir=${XDG_CACHE_HOME:-$HOME/.cache}/guv
lock=$dir/watchdog.lock
alerts=$dir/alerts
registry=$dir/guvs
mkdir -p "$dir" "$registry"
touch "$alerts"
ncpu=$(sysctl -n hw.ncpu)

sample() {
  load=$(sysctl -n vm.loadavg | awk '{print $3}')
  mem=$(memory_pressure -Q 2>/dev/null | awk '/percentage/{print $NF+0}')
  disk=$(/bin/df -g /System/Volumes/Data | awk 'NR==2{print $4}')
  swap=$(sysctl -n vm.swapusage | awk '{print $6}')
}

status() {
  echo "load ${load}/${ncpu} cores, memory ${mem}% free, swap ${swap} used, disk ${disk}G free"
}

breaches() {
  local out=""
  awk -v l="$load" -v n="$ncpu" -v k="$LOAD_PER_CORE" 'BEGIN{exit !(l > n*k)}' \
    && out+="load ${load} on ${ncpu} cores; "
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
  if [[ -n $holder ]] && ! kill -0 "$holder" 2>/dev/null; then
    rm -rf "$lock"
  fi
  return 1
}

release_lock() {
  [[ $(cat "$lock/pid" 2>/dev/null) == "$$" ]] && rm -rf "$lock"
}

list_guvs() {
  local f
  for f in "$registry"/*; do
    [[ -f $f ]] || continue
    if kill -0 "${f##*/}" 2>/dev/null; then cat "$f"; else rm -f "$f"; fi
  done
}

top_procs() {
  local pid cpu rss cwd
  ps -Ao pid=,pcpu=,rss= -r | head -12 | while read -r pid cpu rss; do
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
    printf '%5s%% %6sM  %-16s %s\n' "$cpu" "$((rss / 1024))" \
      "$(ps -o comm= -p "$pid" | awk -F/ '{print $NF}')" "${cwd:-?}"
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

ask() {
  local target=$1 asks=$dir/asks last
  touch "$asks"
  last=$(awk -F'\t' -v g="$target" '$2 == g' "$asks" | tail -1)
  if [[ -n $last ]] && (( $(date +%s) - ${last%%$'\t'*} < COOLDOWN )); then
    echo "already asked by ${last##*$'\t'}"
    return 1
  fi
  printf '%s\t%s\t%s\n' "$(date +%s)" "$target" "${GUV% *}" >> "$asks"
}

case ${1:-} in
  guvs) list_guvs; exit 0 ;;
  top) top_procs; exit 0 ;;
  books) books; exit 0 ;;
  post) printf '%s %s: %s\n' "$(date '+%m-%d %H:%M')" "${GUV% *}" "${2:?usage: watchdog.sh post <text>}" >> "$dir/board"; exit 0 ;;
  board) tail -20 "$dir/board" 2>/dev/null; exit 0 ;;
  ask) ask "${2:?usage: watchdog.sh ask <guvnor>}"; exit ;;
esac

sample
if [[ ${1:-} == status ]]; then
  status
  exit 0
fi

trap 'release_lock; rm -f "$registry/$$"' EXIT
[[ -n ${GUV:-} ]] && echo "$GUV" > "$registry/$$"
echo "watchdog: $(status)"
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
