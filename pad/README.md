# pad

A side pane for Claude Code that shows a short running summary of the task in hand, in your own language, with the latest question or event in a frame at the bottom.

While Claude asks you clarifying questions, it is easy to lose track of what has been settled; once the work starts, it is easy to lose track of how far it has got. With the pad on, Claude keeps a summary file up to date after every answer and at every change of stage, and the pane shows it beside the chat. The file stays in the folder afterwards as a record of the task.

## What the summary shows

- **Status**: Clarifying, Planning, In progress, Waiting, Checking or Done.
- **Goal** and **Confirmed**: what the task is and what has been settled.
- **Plan**: the steps in order, each marked `[x]` done, `[~]` in progress or `[ ]` not started.
- **Done** and **Open**: results so far, and what is still undecided.
- **Latest**, in the frame: the last question and answer, or what just happened.

A quick question or a one-step request gets no summary file.

## Install from the zip

1. Unzip `pad.zip` somewhere you will keep it, for example `~/claude-plugins/pad`.
2. Start Claude Code with it loaded:

   ```
   claude --plugin-dir ~/claude-plugins/pad
   ```

3. Type `/pad`. The first time, Claude asks which language you want the summary in.

To load it in every session without the flag, add the folder to the `env` block of `~/.claude/settings.json`, using the full path:

```json
{
  "env": {
    "CLAUDE_CODE_PLUGIN_DIRS": "/Users/you/claude-plugins/pad"
  }
}
```

## When it is on

- **Automatically** when `skill-creator` starts, whether Claude calls it or you type `/skill-creator`. The pad only records the interview; `skill-creator` still decides what to ask and do.
- **On request** with `/pad`, for any other task.

It stays on for the rest of the session. `/pad off` turns it off and closes the pane.

## Your language

The first time the pad is on, Claude asks which language you want the summary in and remembers it for later sessions. To change it:

```
/pad language Japanese
```

The chat itself stays in whatever language you write in.

## Where the summary lives

`tasks/<task-name>/summary.md` in the folder you are working in. The pane shows the summary Claude wrote last in this session and checks it for changes every two seconds. Summaries left by earlier tasks, or written by another session in the same folder, are not shown; until Claude writes one, the pane says there is no summary yet.

## Requirements

A recent Claude Code with plugin hook modules. The pane docks beside the chat in a terminal at least 110 columns wide with fullscreen rendering; otherwise it sits above the prompt. Without the pane, the summary is still a plain Markdown file you can open.
