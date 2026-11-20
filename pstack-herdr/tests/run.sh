#!/usr/bin/env bash
# Checks the session-start hook.
# Usage: bash tests/run.sh
set -uo pipefail

src="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d "${TMPDIR:-/tmp}/pstack-herdr-test.XXXXXX")
trap 'rm -rf "$work"' EXIT
passed=0 failed=0

check() {
  if eval "$2"; then
    passed=$((passed + 1)); printf 'ok    %s\n' "$1"
  else
    failed=$((failed + 1)); printf 'FAIL  %s\n' "$1"
  fi
}

hook() { HC_TERMINAL_ID=t0 CLAUDE_PLUGIN_ROOT="$1" bash "$src/hooks/session-start.sh"; }
context() { hook "$1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])'; }

check "hook is silent outside Herdr" '[[ -z "$(env -u HC_TERMINAL_ID CLAUDE_PLUGIN_ROOT="$src" bash "$src/hooks/session-start.sh")" ]]'
check "hook names the bridge" 'context "$src" | grep -qF "$src/bridge.md"'
check "hook names the gpt- prefix" 'context "$src" | grep -q "starting with gpt-"'

# The hook's JSON stays valid with control characters and quotes in the plugin path.
T=$'\t'
mkdir -p "$work/a${T}b\"c"
check "hook JSON valid with a tab and a quote in the path" 'context "$work/a${T}b\"c" >/dev/null 2>&1'

# The bridge's table and the hook agree on the programs.
for p in codex; do
  check "bridge lists $p" 'grep -q "| \`$p\` |" "$src/bridge.md"'
done

printf '\n%d passed, %d failed\n' "$passed" "$failed"
(( failed == 0 ))
