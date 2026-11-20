---
name: pstack-herdr
description: Set up pstack with agents from other companies in one go. Checks which agents and models this machine can run, runs pstack's own setup (/pstack:setup-pstack), then spreads pstack's review seats across the companies it found, using each one's strongest model: GPT through Codex, Gemini through Antigravity (agy) and Grok through the Grok CLI, next to Claude. Required before the first use of pstack-herdr and again when an agent program is added, logged in or removed. Use for /pstack-herdr, "set up pstack-herdr", "set up pstack with Codex, Gemini or Grok", "use Codex in pstack", "change the pstack GPT, Gemini or Grok model" or "change the pstack budget".
---

# Set up pstack-herdr

Find out which models this machine can run, run pstack's own setup, then make pstack's "other vendor" seats name a model this plugin can start in a Herdr tab. Both setups write `~/.claude/rules/pstack-models.md`, which Claude Code loads into every new session.

Read `../../bridge.md` first.

## Steps

### 1. Check what this machine can run

Run the detection script. It checks each program in `agents.tsv`: installed, logged in, and which models it offers. It saves the result to the state file (`~/.claude/pstack-herdr/state.tsv`, or `$PSTACK_HERDR_HOME/state.tsv` when that is set), which the session-start check, the bridge and step 3 read.

```sh
bash ../../scripts/detect.sh
```

Use the script's absolute path. If it exits 1, show its message and stop: the saved state was not changed. The Claude models are the `model` values that the `Agent` tool schema lists.

Show the user one table: each agent program with its company, state, default and models, then the Claude models. For each state other than `ready`, say what to do, then suggest rerunning setup:

| State | What to do |
| --- | --- |
| `not-installed` | Install the program. |
| `not-logged-in` | Log in: `codex login`, `grok login`, or start `agy` once and sign in. |
| `timed-out` | The login or model check took over 15 seconds. Check the network and rerun. |
| `models-failed` | The model list command failed. Run it by hand (`codex debug models`, `agy models` or `grok models`) to see why. |
| `no-models` | The program offers no model with this prefix. Start the program once and check the account. |
| `bad-row` | The row in `agents.tsv` is missing a column. Fix the row. |

If `$HC_TERMINAL_ID` is not set, say that the seats only reach a tab in sessions started inside Herdr, then go on.

### 2. Run pstack's own setup

Find pstack's folder, the one that holds `skills/setup-pstack/SKILL.md`: the base directory of the loaded `pstack:setup-pstack` skill, two levels up; else the `installPath` of `pstack@...` in `~/.claude/plugins/installed_plugins.json`. If there is none, stop and tell the user to install the pstack plugin first.

Before running it, read `~/.claude/rules/pstack-models.md` if it exists, and note each non-Claude name in it that is not in a `ready` row of step 1. The bridge's `setup-pstack` section lets these pass pstack's validation; step 3 replaces them.

Read `docs/harness/claude-code.md` in that folder, then `skills/setup-pstack/SKILL.md`, and follow it to the end, including its budget question and its role confirmation. The bridge's `setup-pstack` section applies throughout: names of `ready` agents from step 1 are offered only for the three panel roles, and the budget never changes them.

pstack's setup keeps the other-vendor names a previous run of this setup wrote, as the user's choices. Its steps 7 and 8 offer verification skills. Let them run as written.

When it finishes, `~/.claude/rules/pstack-models.md` exists. Read it.

### 3. Choose the seats

Only three roles take another vendor. Code, prose, swarm workers and verification stay on Claude: pstack never puts another vendor there.

If no agent is `ready` in step 1, skip to step 5. Leave any non-Claude name in the three roles and say that its seat runs on Claude, or is skipped for the judge, until setup finds its agent ready.

Otherwise show the user the current value of each of the three roles and a proposal, then ask with `AskUserQuestion` whether to accept it or change a seat. Offer only models found in step 1.

The proposal spreads each list across as many companies as it can, so the seats see the work differently. A company is a `vendor` in the state file; Claude is the company `anthropic`. Each company's model is its `default` from step 1, its strongest model on this machine.

| Role | Proposal |
| --- | --- |
| `arena runners` | as many entries as pstack's setup wrote: one Claude entry, then one model from each `ready` company in state-file order, until the list is full |
| `arena cross-judge pool` | one model from each `ready` company in state-file order, then the list's Claude entries |
| `interrogate reviewers` | the same as `arena runners` |

For example, with Codex, Antigravity and Grok ready and a three-entry list, the runners are `opus medium`, `gpt-6.2-astra`, `gemini-4-neon-high`, and the judge pool is `gpt-6.2-astra`, `gemini-4-neon-high`, `grok-4.7`, `opus medium`.

- Never put two models from the same company in one list, Claude included, unless there are more seats than companies. Then fill the remaining seats with the Claude entries pstack's setup wrote.
- When there are more `ready` companies than seats, say which ones were left out, so the user can swap one in.
- When a list already names a model of a `ready` company, propose keeping that one for its company instead of the `default`, in the same place in the list.
- Keep the effort pstack's setup gave each Claude entry. An `inherit-parent` entry counts as Claude.
- A non-Claude name that step 1 did not find is stale, including those noted in step 2: mark it and propose its company's `default` instead, or another company's if its company is not ready.

The judge is never from the session's vendor, and pstack takes the first entry from another vendor, so the other-vendor names go first in `arena cross-judge pool`.

The final check in show-me-your-work and a second opinion name no model. They use the `default` that step 1 found for the first `ready` agent.

### 4. Write the file

Change only the three role lines in `~/.claude/rules/pstack-models.md`. Keep every other line as pstack's setup wrote it, and add this comment line under its other comments if it is missing:

```
# Non-Claude names run as their own agent in a Herdr tab, through the pstack-herdr plugin.
```

### 5. Tell the user

- The list applies to new sessions.
- Rerun this setup after installing, logging in to or removing an agent program, or to change the budget. The session-start check reminds them when a program it found has gone or a missing one is now installed. It cannot notice a logout or a model that was withdrawn; a seat that fails to start then says so.
- Run this setup rather than `/pstack:setup-pstack` on its own. It runs pstack's setup and then checks the other-vendor seats.
