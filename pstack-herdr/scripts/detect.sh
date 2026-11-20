#!/usr/bin/env bash
# Checks each agent program in agents.tsv on this machine: installed, logged in,
# and which models it offers. Writes the result to the state file that the
# session-start hook and bridge.md read, and prints it.
# Exits 1, leaving the saved state as it was, when it cannot read agents.tsv or save.
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
registry="$root/agents.tsv"
state_dir="${PSTACK_HERDR_HOME:-$HOME/.claude/pstack-herdr}"
state="$state_dir/state.tsv"

fail() {
  printf 'pstack-herdr: %s The saved state was not changed.\n' "$1" >&2
  exit 1
}

# Runs a check with a time limit, since login checks can stall on a network call.
# The check gets its own process group, so a timeout stops everything it started,
# and writes to a file, so nothing left running can hold a pipe open.
limited() {
  local seconds=$1 cmd=$2 out=$3
  set -m
  bash -c "$cmd" </dev/null >"$out" 2>/dev/null &
  local pid=$! waited=0
  set +m
  while kill -0 "$pid" 2>/dev/null; do
    if (( waited >= seconds * 10 )); then
      { kill -TERM -- "-$pid"; wait "$pid"; } 2>/dev/null
      return 124
    fi
    sleep 0.1
    waited=$((waited + 1))
  done
  wait "$pid"
}

[[ -r "$registry" ]] || fail "Cannot read $registry. Reinstall the plugin."
mkdir -p "$state_dir" 2>/dev/null || fail "Cannot create $state_dir."
# Each run writes its own file, so two runs at once never mix their rows.
tmp=$(mktemp "$state_dir/state.XXXXXX" 2>/dev/null) || fail "Cannot write in $state_dir."
out=$(mktemp "$state_dir/check.XXXXXX" 2>/dev/null) || { rm -f "$tmp"; fail "Cannot write in $state_dir."; }
trap 'rm -f "$tmp" "$out"' EXIT

{
  printf '# Written by pstack-herdr setup on %s. Rerun /pstack-herdr to refresh.\n' "$(date '+%Y-%m-%d %H:%M')"
  printf 'prefix\tprogram\tstate\tdefault\tmodels\n'
} >"$tmp" || fail "Cannot write in $state_dir."

while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line%$'\r'}
  # Split on single tabs, so an empty column stays empty instead of shifting the rest.
  IFS=$'\x1f' read -r prefix program args default login models tested <<<"${line//$'\t'/$'\x1f'}"
  [[ -z "$prefix" || "$prefix" == \#* || "$prefix" == prefix ]] && continue
  found="" chosen=""
  if [[ -z "$program" || -z "$login" || -z "$models" ]]; then
    status="bad-row"
  elif ! command -v "$program" >/dev/null 2>&1; then
    status="not-installed"
  else
    limited 15 "$login" "$out"
    case $? in
      0) status="" ;;
      124) status="timed-out" ;;
      *) status="not-logged-in" ;;
    esac
    if [[ -z "$status" ]]; then
      limited 15 "$models" "$out"
      case $? in
        0)
          found=$(awk -v p="$prefix" 'index($0, p) == 1 && !seen[$0]++' "$out" | tr '\n' ' ' | sed 's/ $//')
          if [[ -z "$found" ]]; then status="no-models"; else status="ready"; fi
          ;;
        124) status="timed-out" ;;
        *) status="models-failed" ;;
      esac
    fi
  fi
  # The default must be one of the models found; otherwise take the first one listed.
  if [[ -n "$found" ]]; then
    chosen=${found%% *}
    [[ " $found " == *" $default "* && -n "$default" ]] && chosen=$default
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$prefix" "$program" "$status" "$chosen" "$found" >>"$tmp" || fail "Cannot write in $state_dir."
  printf '%-8s %-10s %-14s %-16s %s\n' "$prefix" "$program" "$status" "$chosen" "$found"
done <"$registry"

mv -f "$tmp" "$state" 2>/dev/null || fail "Cannot save $state."
printf '\nSaved to %s\n' "$state"
