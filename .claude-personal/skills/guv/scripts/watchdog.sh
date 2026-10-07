#!/usr/bin/env bash
# Machine watchdog shared by every guvnor on this machine.
#
#   watchdog.sh          run in the background; exits with the alert as its
#                        output when the machine needs action, which wakes the
#                        guvnor that started it. Restart it after acting.
#   watchdog.sh status   print one line of current readings and exit.
#   watchdog.sh guvs     list the guvnors whose watchdogs are running.
#
# GUV="<ListAgents name> <project>" registers the running instance, so other
# guvnors can find this one with `watchdog.sh guvs`. Entries die with it.
#
# Every running instance waits on one alert log, but only one of them (the
# holder of the lock) samples, so several guvnors see the same alert once
# rather than each raising its own. A threshold must hold for two samples in a
# row, so a single spike does not wake anyone. When the sampler exits, another
# instance takes the lock on its next tick.
set -uo pipefail

INTERVAL=${INTERVAL:-60}
LOAD_PER_CORE=${LOAD_PER_CORE:-4}   # 5-minute load average per core
MEM_FREE_MIN=${MEM_FREE_MIN:-10}    # percent free, from memory_pressure
DISK_FREE_MIN=${DISK_FREE_MIN:-50}  # GB free on the data volume

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

if [[ ${1:-} == guvs ]]; then
  list_guvs
  exit 0
fi

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
      echo "$(date '+%H:%M') $now" >> "$alerts"
      now=""
    fi
    prev=$now
  fi
  if (( $(wc -l < "$alerts") > seen )); then
    echo "watchdog: $(tail -1 "$alerts")"
    exit 1
  fi
done
