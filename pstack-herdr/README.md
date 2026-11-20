# pstack-herdr

Lets [pstack](https://github.com/cursor/plugins/tree/main/pstack) use agents from other companies in Claude Code, by starting them in Herdr tabs.

pstack's review panels are designed to mix models from different companies: one arena runner, the arena judge, one interrogate reviewer and the final check before a handoff. In Claude Code the built-in sub-agent tool only runs Claude models, so pstack quietly runs those seats on Claude. With this plugin, a seat that names another company's model opens a Herdr tab running that company's agent with that model, gets the same brief, and reports back to the main chat.

| Company | Agent program | Model names | Strongest model setup prefers |
| --- | --- | --- | --- |
| OpenAI | Codex (`codex`) | `gpt-…` | `gpt-6.2-astra` |
| Google | Antigravity CLI (`agy`) | `gemini-…` | `gemini-4-neon-high`, then `gemini-4-carbon-high`, then `gemini-3.1-pro-high` |
| xAI | Grok CLI (`grok`) | `grok-…` | `grok-4.7` |

Setup checks which of these are installed and logged in, then spreads the review seats across as many companies as it can, next to Claude, using each company's strongest model on your machine. You need only one of them; any you lack are left out.

pstack itself is not changed. Code writing, prose, swarm workers and verification stay on Claude. Only `arena runners`, `arena cross-judge pool` and `interrogate reviewers` take other-company models, plus the final check and second opinion, which name no model.

## What you need

- Claude Code with the `pstack` plugin installed, as pstack's README says.
- Herdr (the `hc` and `herdr-app` commands), with Claude Code started inside it. Outside Herdr the plugin stays silent.
- At least one of the agents above, logged in:
  - Codex: `codex login`, and `python3`, which reads Codex's model list.
  - Antigravity: start `agy` once and sign in. `agy models` should then list Gemini models.
  - Grok: `grok login`. `grok models` should then say you are logged in.
- Each agent must be on the `PATH` of the shells Herdr opens, not only in your current shell.
- Each agent must trust the project folder. Open the project in it once and trust it, or trust a parent folder. Otherwise its tab stops on a trust prompt and waits for you.
- At the end of its work, each seat runs `hc send` to report back. Depending on the agent's sandbox and approval settings, it may ask you before running it. The tab then waits for you; Claude tells you which tab and never answers for you.

Tested end to end with Claude Code 2.1.311, pstack 0.15.46, Codex CLI 0.170.0, hc 0.1.21 and herdr-app 0.1.16, on macOS. The Antigravity (agy 1.5.9) and Grok (grok 1.0.89) rows pass setup's checks but have not yet run a seat end to end.

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

1. In a Claude Code session started inside Herdr with the plugin loaded, type `/pstack-herdr`. It checks which agent programs this machine has, whether they are logged in and which models they offer. Then it runs pstack's own setup (`/pstack:setup-pstack`), which asks for a budget and sets every role, and finally puts the other-company models into the review seats. Both write the model list pstack reads (`~/.claude/rules/pstack-models.md`). Until setup has run, Claude reminds you at the start of each session.
2. Start a new session and use pstack as usual, for example `/pstack:arena`. The other-company seats open as tabs named after the run and the seat.

Each seat works in its own folder, `<project>/.pstack-seats/<run>/<seat>/`, which is kept after the run so you can read the briefs and reports. In a git repository, the plugin adds `.pstack-seats/` to `.git/info/exclude`, so it is never committed. Delete the folder when you no longer need it.

When an other-company seat cannot start, an arena runner or interrogate reviewer runs on Claude instead. The arena judge, the final check and a second opinion must come from another company, so they are skipped instead. Claude says which seats fell back or were skipped, and why.

## When to run setup again

- After installing, logging in to or removing an agent program. The session-start check notices a program that has gone, one that is now installed, or a new row in `agents.tsv`, and reminds you. It cannot notice a logout.
- To change the budget. Run this setup rather than `/pstack:setup-pstack` on its own: it runs pstack's setup, then checks the other-company seats.
- To change which model a seat uses. You can also edit the three role lines in `~/.claude/rules/pstack-models.md` directly.

## Add another company

`agents.tsv` holds one row per agent program: the prefix its model names share, the program, its arguments, the models to prefer (strongest first; the first one found is used), a command that checks the login, a command that lists its models, whether it has been tested, and the company that makes its models. Columns are separated by one tab, and arguments are split on spaces. Add a row and run setup. Only the `gpt-` row for Codex has run a seat end to end.

## Files

- `agents.tsv`: the agent programs the plugin knows.
- `bridge.md`: the steps Claude follows to start a seat in a tab and collect its report.
- `scripts/detect.sh`: the check that setup runs. It saves its result to `~/.claude/pstack-herdr/state.tsv`.
- `hooks/`: at the start of each session, tells Claude where `bridge.md` is and whether setup is needed.
- `skills/pstack-herdr/`: the setup command, `/pstack-herdr`.
- `tests/run.sh`: checks the two scripts against made-up agents. Run `bash pstack-herdr/tests/run.sh`.

After editing, from the repository root: `claude plugin validate pstack-herdr`.
