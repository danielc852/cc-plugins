#!/usr/bin/env bash
# Checks detect.sh and the session-start hook against made-up agents.
# Works on a copy of the plugin in a temporary folder; never touches the saved state.
# Usage: bash tests/run.sh   (takes about 20 seconds, for the time-limit check)
set -uo pipefail

src="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d "${TMPDIR:-/tmp}/pstack-herdr-test.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
export PATH="$work/bin:$PATH"
passed=0 failed=0

check() {
  if eval "$2"; then
    passed=$((passed + 1)); printf 'ok    %s\n' "$1"
  else
    failed=$((failed + 1)); printf 'FAIL  %s\n' "$1"
  fi
}

# Makes a fresh plugin copy whose agents.tsv holds the given text, and a fresh state folder.
plugin() {
  rm -rf "$work/p" "$work/s"
  cp -R "$src" "$work/p"
  rm -rf "$work/p/tests"
  printf '%s' "$1" >"$work/p/agents.tsv"
  export PSTACK_HERDR_HOME="$work/s"
}
detect() { bash "$work/p/scripts/detect.sh" >"$work/out" 2>&1; }
row() { awk -F'\t' -v p="$1" '$1 == p' "$work/s/state.tsv"; }
hook() { HC_TERMINAL_ID=t0 CLAUDE_PLUGIN_ROOT="$work/p" bash "$work/p/hooks/session-start.sh"; }
context() { hook | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])'; }

printf '#!/bin/sh\nexit 0\n' >"$work/bin/zzprog"; chmod +x "$work/bin/zzprog"
T=$'\t'

# An empty args column must not shift the later columns.
plugin "zz-${T}zzprog${T}${T}zz-1${T}true${T}echo zz-1${T}no${T}v"$'\n'
detect
check "empty column keeps columns in place" '[[ "$(row zz-)" == "zz-${T}zzprog${T}ready${T}zz-1${T}zz-1${T}v" ]]'

# A last row without a final newline is still read, by detect and by the hook.
plugin "zz-${T}zzprog${T}-m {model}${T}zz-1${T}true${T}echo zz-1${T}no${T}v"
detect
check "last row without newline is read" '[[ -n "$(row zz-)" ]]'
check "hook sees no change after setup" '! context | grep -q "Setup is needed"'

# The default must be one of the models found; otherwise the first one listed.
plugin "zz-${T}zzprog${T}${T}zz-9${T}true${T}printf \"zz-2\\nzz-1\\n\"${T}no${T}v"$'\n'
detect
check "unknown default replaced by first model" '[[ "$(row zz- | cut -f4)" == zz-2 ]]'

# Of several preferred models, the first one found wins.
plugin "zz-${T}zzprog${T}${T}zz-9 zz-1 zz-2${T}true${T}printf \"zz-2\\nzz-1\\n\"${T}no${T}v"$'\n'
detect
check "first preferred model found is the default" '[[ "$(row zz- | cut -f4)" == zz-1 ]]'
check "vendor is saved" '[[ "$(row zz- | cut -f6)" == v ]]'

# A prefix is a literal start, not a pattern.
plugin "z.-${T}zzprog${T}${T}${T}true${T}echo zz-1${T}no${T}v"$'\n'
detect
check "prefix matched literally" '[[ "$(row z.- | cut -f3)" == no-models ]]'

# Login and model checks: not installed, logged out, failed list, missing column.
plugin "aa-${T}nosuchprog${T}${T}${T}true${T}echo aa-1${T}no${T}v
bb-${T}zzprog${T}${T}${T}false${T}echo bb-1${T}no${T}v
cc-${T}zzprog${T}${T}${T}true${T}echo cc-1; exit 1${T}no${T}v
dd-${T}zzprog${T}${T}${T}${T}echo dd-1${T}no${T}v
ee-${T}zzprog${T}${T}${T}true${T}echo ee-1${T}no
"
detect
check "missing program is not-installed" '[[ "$(row aa- | cut -f3)" == not-installed ]]'
check "failed login is not-logged-in" '[[ "$(row bb- | cut -f3)" == not-logged-in ]]'
check "failing model list is models-failed" '[[ "$(row cc- | cut -f3)" == models-failed ]]'
check "row without login is bad-row" '[[ "$(row dd- | cut -f3)" == bad-row ]]'
check "row without vendor is bad-row" '[[ "$(row ee- | cut -f3)" == bad-row ]]'

# A hung model list stops at the time limit, with everything it started.
plugin "zz-${T}zzprog${T}${T}${T}true${T}sleep 47 | cat; echo zz-1${T}no${T}v"$'\n'
start=$(date +%s); detect; took=$(( $(date +%s) - start ))
check "hung model list stops within 17 s (took ${took}s)" '(( took <= 17 ))'
check "hung model list is timed-out" '[[ "$(row zz- | cut -f3)" == timed-out ]]'
check "nothing it started is left running" '! pgrep -f "sleep 47" >/dev/null'

# Codex's row lists only visible models, best first.
cat >"$work/bin/codex" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "login status") exit 0 ;;
  "debug models") echo '{"models":[{"slug":"gpt-b","visibility":"list","priority":2},{"slug":"gpt-hidden","visibility":"hide","priority":3},{"slug":"gpt-a","visibility":"list","priority":1}]}' ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$work/bin/codex"
# agy prints a progress line, then one model per line with a tab before its title.
cat >"$work/bin/agy" <<'EOF'
#!/bin/sh
[ "$1" = models ] || exit 2
printf 'Fetching available models...\n'
printf 'gemini-4-carbon-high\tGemini 4 Carbon (High)\ngemini-4-neon-high\tGemini 4 Neon (High)\ngemini-3.1-pro-high\tGemini 3.1 Pro (High)\n'
EOF
chmod +x "$work/bin/agy"
# grok prints the login line, then its models marked with * or -.
cat >"$work/bin/grok" <<'EOF'
#!/bin/sh
[ "$1" = models ] || exit 2
printf 'You are logged in with grok.com.\n\nDefault model: grok-4.7\n\nAvailable models:\n  * grok-4.7 (default)\n  - grok-4.7-build-fast\n  - grok-4.6\n'
EOF
chmod +x "$work/bin/grok"
plugin "$(cat "$src/agents.tsv")"$'\n'
detect
check "codex row lists visible models in order" '[[ "$(row gpt- | cut -f5)" == "gpt-a gpt-b" ]]'
check "codex default falls back to a listed model" '[[ "$(row gpt- | cut -f4)" == gpt-a ]]'
check "agy row lists its models without the progress line" '[[ "$(row gemini- | cut -f5)" == "gemini-4-carbon-high gemini-4-neon-high gemini-3.1-pro-high" ]]'
check "agy default is its strongest preferred model" '[[ "$(row gemini- | cut -f4)" == gemini-4-neon-high ]]'
check "grok row lists its models" '[[ "$(row grok- | cut -f5)" == "grok-4.7 grok-4.7-build-fast grok-4.6" ]]'
check "grok default is grok-4.7" '[[ "$(row grok- | cut -f4)" == grok-4.7 ]]'
check "each shipped row keeps its vendor" '[[ "$(cut -f6 "$work/s/state.tsv" | grep -v "^#" | tr "\n" " ")" == "vendor openai google xai " ]]'
# grok without a login line is not logged in.
printf '#!/bin/sh\nprintf "Not logged in.\\n"\n' >"$work/bin/grok"
detect
check "grok without a login is not-logged-in" '[[ "$(row grok- | cut -f3)" == not-logged-in ]]'
rm "$work/bin/agy" "$work/bin/grok"

# A missing agents.tsv fails and keeps the saved state.
cp "$work/s/state.tsv" "$work/saved"
rm "$work/p/agents.tsv"
detect; code=$?
check "missing agents.tsv exits 1" '(( code == 1 ))'
check "missing agents.tsv keeps the saved state" 'cmp -s "$work/s/state.tsv" "$work/saved"'
check "hook asks to reinstall when agents.tsv is missing" 'context | grep -q "reinstall the plugin"'

# A state folder that cannot be made fails.
plugin "zz-${T}zzprog${T}${T}${T}true${T}echo zz-1${T}no${T}v"$'\n'
: >"$work/s"
detect; code=$?
check "unwritable state folder exits 1" '(( code == 1 ))'
rm -f "$work/s"

# Two runs at once each save a complete file and leave no temporary files.
plugin "zz-${T}zzprog${T}${T}${T}true${T}sleep 1; echo zz-1${T}no${T}v
yy-${T}zzprog${T}${T}${T}true${T}echo yy-1${T}no${T}v
"
bash "$work/p/scripts/detect.sh" >/dev/null 2>&1 &
bash "$work/p/scripts/detect.sh" >/dev/null 2>&1
wait
check "parallel runs save a complete file" '[[ $(grep -c "ready" "$work/s/state.tsv") == 2 ]] && grep -q "^prefix" "$work/s/state.tsv"'
check "parallel runs leave no temporary files" '[[ $(ls "$work/s") == state.tsv ]]'

# The hook names only the agents that changed.
plugin "zz-${T}zzprog${T}${T}${T}true${T}echo zz-1${T}no${T}v
qq-${T}qqprog${T}${T}${T}true${T}echo qq-1${T}no${T}v
"
detect
check "hook is silent outside Herdr" '[[ -z "$(env -u HC_TERMINAL_ID CLAUDE_PLUGIN_ROOT="$work/p" bash "$work/p/hooks/session-start.sh")" ]]'
printf '#!/bin/sh\nexit 0\n' >"$work/bin/qqprog"; chmod +x "$work/bin/qqprog"
check "hook notices a newly installed program" 'context | grep -q "qqprog is now installed"'
check "hook does not blame a ready agent" '! context | grep -q "zzprog"'
rm "$work/bin/qqprog"
printf 'prefix\tprogram\tstate\tmodels\nzz-\tzzprog\tready\tzz-1\n' >"$work/s/state.tsv"
check "hook notices a state file from an older version" 'context | grep -q "older version"'

# The hook's JSON stays valid with control characters in a path.
mkdir -p "$work/a${T}b"
check "hook JSON valid with a tab in the state path" 'PSTACK_HERDR_HOME="$work/a${T}b" context >/dev/null 2>&1'

printf '\n%d passed, %d failed\n' "$passed" "$failed"
(( failed == 0 ))
