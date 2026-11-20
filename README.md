# cc-plugins

Plugins for Claude Code.

| Plugin | What it does |
| --- | --- |
| [pad](pad/README.md) | A side pane that shows a short running summary of the task in hand, in your own language. |
| [pstack-herdr](pstack-herdr/README.md) | Lets [pstack](https://github.com/cursor/plugins/tree/main/pstack)'s review panels use agents from other companies (Codex for GPT, Antigravity for Gemini, Grok) by starting them in Herdr tabs. Needs pstack, Herdr and at least one of those agents. |

## Install

In Claude Code, once per computer:

```
/plugin marketplace add danielc852/cc-plugins
/plugin install pad@cc-plugins
/plugin install pstack-herdr@cc-plugins
```

Install only the plugins you want. pstack-herdr can also be loaded only in sessions started inside Herdr: see [its README](pstack-herdr/README.md#install).

To get a newer version later:

```
/plugin marketplace update cc-plugins
```
