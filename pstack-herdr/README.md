# pstack-herdr

pstack normally runs every seat as a Claude subagent. With this plugin, a seat that names a GPT model runs OpenAI's own agent, Codex, in a Herdr tab instead.

[pstack](https://github.com/cursor/plugins/tree/main/pstack)'s review panels are designed to mix models from different companies: arena runners, the arena judge, interrogate reviewers and the final check before a handoff. In Claude Code the built-in subagent tool only runs Claude models, so without this plugin pstack quietly runs those seats on Claude. With it, each such seat opens a Herdr tab, gets the same brief, and reports back to the main chat.

| Model name starts with | Company | Agent program |
| --- | --- | --- |
| `gpt-` | OpenAI | Codex (`codex`) |

pstack itself is not changed. Code writing, prose, swarm workers and verification stay on Claude. Only `arena runners`, `arena cross-judge pool` and `interrogate reviewers` take other-company models, plus the final check and second opinion, which name no model.

## What you need

- Claude Code with the `pstack` plugin installed, as pstack's README says.
- Herdr (the `hc` and `herdr-app` commands), with Claude Code started inside it. Outside Herdr the plugin stays silent.
- Codex (`codex`), logged in with `codex login`.
- Codex must be on the `PATH` of the shells Herdr opens, not only in your current shell.
- Codex must trust the project folder. Open the project in Codex once and trust it, or trust a parent folder. Otherwise its tab stops on a trust prompt and waits for you.
- At the end of its work, each seat runs `hc send` to report back. Depending on Codex's sandbox and approval settings, it may ask you before running it. The tab then waits for you; Claude tells you which tab and never answers for you.

Tested end to end with Claude Code 2.1.311, pstack 0.15.46, Codex CLI 0.170.0, hc 0.1.21 and herdr-app 0.1.16, on macOS.

## Install

There are two ways. Pick one.

**From the marketplace.** In Claude Code, once per computer:

```
/plugin marketplace add danielc852/cc-plugins
/plugin install pstack-herdr@cc-plugins
```

It then loads in every session, and stays silent outside Herdr. To update: `/plugin marketplace update cc-plugins`.

**Only in sessions started inside Herdr.** Clone the repository and load the plugin folder when Claude Code starts:

```sh
git clone https://github.com/danielc852/cc-plugins ~/cc-plugins
claude --plugin-dir ~/cc-plugins/pstack-herdr
```

To do this for every Claude Code session you start inside Herdr, and no other, add this line to `~/.zshrc` or `~/.bashrc`:

```sh
[ -n "$HC_TERMINAL_ID" ] && alias claude='claude --plugin-dir ~/cc-plugins/pstack-herdr'
```

To update, run `git pull` in `~/cc-plugins`.

## Use it

1. Write the models you want in the three review roles of `~/.claude/rules/pstack-models.md`, the list pstack reads. Edit the file directly, or run `/pstack:setup-pstack`, which accepts these names in those roles. For example:

   ```
   arena runners: gpt-6.1-sol, opus medium, gpt-6.2-sol
   arena cross-judge pool: gpt-6.2-astra, opus medium
   interrogate reviewers: gpt-6.1-sol, opus medium, gpt-6.2-sol
   ```

   Use the exact names Codex offers: `codex debug models` lists them. Put a non-Claude name first in `arena cross-judge pool`: the judge, the final check and a second opinion use the first one whose program is installed.
2. Start a new session inside Herdr and use pstack as usual, for example `/pstack:arena`. The other-company seats open as tabs named after the run and the seat.

Each seat works in its own folder, `<project>/.pstack-seats/<run>/<seat>/`, which is kept after the run so you can read the briefs and reports. In a git repository, the plugin adds `.pstack-seats/` to `.git/info/exclude`, so it is never committed. Delete the folder when you no longer need it.

When an other-company seat cannot start, because its program is not installed, it is not logged in or the model name is wrong, an arena runner or interrogate reviewer runs on Claude instead. The arena judge, the final check and a second opinion must come from another company, so they move to the next non-Claude name in `arena cross-judge pool`, or are skipped. Claude says which seats fell back or were skipped, and why.

## Changes in 0.7.0

The plugin is now much simpler. It only teaches Claude how to run a `gpt-` seat in a Codex tab; you choose the models.

- **Removed:** the `/pstack-herdr` setup command, `agents.tsv`, `scripts/detect.sh`, the saved state in `~/.claude/pstack-herdr/` (safe to delete) and the session-start reminders to rerun setup.
- **Removed:** Gemini (agy) and Grok, added in 0.6.0. Only Codex and Claude remain.
- **Now:** write the model names in `~/.claude/rules/pstack-models.md` yourself, or through `/pstack:setup-pstack`. Your existing `gpt-` names keep working.
- **Trade-off:** nothing checks the login or model names ahead of time. A wrong name or a logged-out Codex shows up when the seat starts: a runner or reviewer then runs on Claude, and Claude tells you why.

## Add another company

Add a line to the table under "Agents" in `bridge.md`: the start its model names share, the company, the program and its arguments before the task, with `<model>` where the model name goes. Add the start to the session-start note in `hooks/session-start.sh` too.

## Files

- `bridge.md`: which program runs which model name, and the steps Claude follows to start a seat in a tab and collect its report.
- `hooks/`: at the start of each session inside Herdr, tells Claude where `bridge.md` is.
- `tests/run.sh`: checks the session-start note. Run `bash pstack-herdr/tests/run.sh`.

After editing, from the repository root: `claude plugin validate pstack-herdr`.
