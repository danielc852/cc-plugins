#!/usr/bin/env bash
# Tells each new session where the bridge is, and whether setup is needed.
# Reads only the saved setup result and checks whether its programs are installed,
# so the session never waits on a login or network check.
set -uo pipefail

# Outside Herdr the plugin stays silent, so pstack behaves exactly as without it.
[[ -n "${HC_TERMINAL_ID:-}" ]] || exit 0

root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
state="${PSTACK_HERDR_HOME:-$HOME/.claude/pstack-herdr}/state.tsv"

json_escape() {
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}
  s=${s//$'\t'/\\t}; s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}
  printf '%s' "$s" | tr -d '\000-\037'
}

reasons=""
add() { reasons="${reasons:+$reasons; }$1"; }

if [[ ! -r "$root/agents.tsv" ]]; then
  add "the plugin's agents.tsv is missing, so reinstall the plugin first"
elif [[ ! -f "$state" ]]; then
  add "setup has never run on this machine"
else
  grep -q "^prefix	program	state	default	models	vendor" "$state" || add "setup ran with an older version of the plugin"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    IFS=$'\x1f' read -r prefix program _ <<<"${line//$'\t'/$'\x1f'}"
    [[ -z "$prefix" || "$prefix" == \#* || "$prefix" == prefix ]] && continue
    status=$(awk -F'\t' -v p="$prefix" -v q="$program" '$1 == p && $2 == q { print $3; exit }' "$state")
    if [[ -z "$status" ]]; then
      add "the agent $program was added to the plugin after setup ran"
    elif [[ "$status" == ready ]] && ! command -v "$program" >/dev/null 2>&1; then
      add "$program was ready at setup but is no longer installed"
    elif [[ "$status" == not-installed ]] && command -v "$program" >/dev/null 2>&1; then
      add "$program is now installed"
    fi
  done <"$root/agents.tsv"
fi

note="The pstack-herdr plugin is loaded. Whenever you follow a pstack skill (poteto-mode, arena, interrogate, swarm, show-me-your-work, setup-pstack or any other), read $root/bridge.md once per session, right after pstack's Claude Code adapter. It replaces the adapter's rule for non-Claude model names: a seat whose model belongs to a ready agent in $state runs as its own agent in a Herdr tab, not on the session model."
if [[ -n "$reasons" ]]; then
  note="$note Setup is needed: $reasons. Tell the user once, early in the session, to run /pstack-herdr. Until it runs, seats of the agents named here follow the bridge's fallback rules, and you say so for each seat. Seats of other ready agents still run in tabs."
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$(json_escape "$note")"
  }
}
EOF
