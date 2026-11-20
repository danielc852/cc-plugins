#!/usr/bin/env bash
# Tells each new session inside Herdr where the bridge is.
set -uo pipefail

# Outside Herdr the plugin stays silent, so pstack behaves exactly as without it.
[[ -n "${HC_TERMINAL_ID:-}" ]] || exit 0

root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

json_escape() {
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}
  s=${s//$'\t'/\\t}; s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}
  printf '%s' "$s" | tr -d '\000-\037'
}

note="The pstack-herdr plugin is loaded. pstack normally runs every seat as a Claude subagent. With this plugin, a seat that names a GPT model (a name starting with gpt-) runs OpenAI's own agent, Codex, in a Herdr tab instead. Whenever you follow a pstack skill (poteto-mode, arena, interrogate, swarm, show-me-your-work, setup-pstack or any other), read $root/bridge.md once per session, right after pstack's Claude Code adapter. It replaces the adapter's rule for non-Claude model names."

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$(json_escape "$note")"
  }
}
EOF
