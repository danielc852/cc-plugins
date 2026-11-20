import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

const PANE = 'pad'
const TITLE = 'Pad'
const COMMAND = 'pad'
// Each task keeps its running summary at tasks/<task>/summary.md, relative
// to the working directory. The pane shows the one this session wrote last,
// never one left by an earlier task or written by another session.
const TASKS = 'tasks'
const FILE = 'summary.md'
const POLL_MS = 2000
// Transparent: the pane keeps the terminal's own background. `columns` is
// asked of the dock, `rows` of the block above the prompt.
const OPEN = {
  id: PANE,
  title: TITLE,
  backgroundColor: 'transparent',
  columns: 56,
  rows: 20,
} as const
// Everything after this marker line is the latest question or event: the
// pane draws it apart, in a frame under the summary. The marker, not a
// heading, so the file's headings can be in any language.
const LATEST = '<!-- latest -->'
// The person's summary language, kept across sessions; unset until they
// are asked the first time the pad is on.
const LANGUAGE = 'language'
const SET_LANGUAGE = 'set_language'
// skill-creator under any plugin prefix (`anthropic-skills:skill-creator`).
const SKILL_CREATOR = /(^|:)skill-creator$/
const TYPED_SKILL_CREATOR = /^\s*\/([\w-]+:)?skill-creator(\s|$)/

// On for the rest of the session once skill-creator starts or /pad is run.
const isActive = atom({ plugin: 'pad', key: 'isActive' } as const, false)

// The task whose summary this session wrote last; empty until it writes one.
const shownTask = atom({ plugin: 'pad', key: 'task' } as const, '')

type Summary = { task: string; path: string; mtimeMs: number }

const current = async ($: EngineInterface): Promise<Summary | undefined> => {
  const task = await read($, shownTask)
  if (task === '') return undefined
  const path = `${TASKS}/${task}/${FILE}`
  const stat = await $.fs.stat(path).catch(() => undefined)
  if (stat === undefined || stat.kind !== 'file') return undefined

  return { task, path, mtimeMs: stat.mtimeMs }
}

// The task a written file is the summary of, or undefined for any other file.
const taskOf = (cwd: string, file: string): string | undefined => {
  const root = `${cwd.replace(/\/+$/, '')}/`
  const [dir, task, name, ...deeper] = (
    file.startsWith(root) ? file.slice(root.length) : file
  ).split('/')
  if (dir !== TASKS || name !== FILE || deeper.length > 0) return undefined

  return task === '' ? undefined : task
}

// After a write or an edit went through: a summary becomes the one shown.
const noteWrite = async (
  $: EngineInterface,
  file: string,
  ran: object,
): Promise<void> => {
  if ('deny' in ran || ('isError' in ran && ran.isError === true)) return
  const task = taskOf(await $.session.cwd(), file)
  if (task === undefined) return
  await update($, shownTask, () => task)
  $.ui.invalidate('ui.render')
}

const split = (text: string): { body: string; latest: string } => {
  const at = text.lastIndexOf(LATEST)
  if (at < 0) return { body: text.trimEnd(), latest: '' }

  return {
    body: text.slice(0, at).trimEnd(),
    latest: text.slice(at + LATEST.length).trim(),
  }
}

const languageOf = async ($: EngineInterface): Promise<string> => {
  const stored = await $.store.get(LANGUAGE).catch(() => undefined)

  return typeof stored === 'string' ? stored.trim() : ''
}

// Turns the pad on for the session and answers the rule the model is given.
const turnOn = async ($: EngineInterface, tool: string): Promise<string> => {
  await update($, isActive, () => true)
  void $.ui.open(OPEN).catch(() => undefined)

  return rule(await languageOf($), tool)
}

// What the model is told while the pad is on.
const rule = (language: string, tool: string): string =>
  [
    '# The pad (running task summary)',
    '',
    'The person has a side pane, "the pad", that shows a short running summary of the task in hand: what was clarified, the plan, and how far the work has got. It reads a file you keep; writing the file is what updates the pane, so never print the summary into the chat instead.',
    '',
    language === ''
      ? `Summary language: not chosen yet. Before your first clarifying question, ask the person once which language they want the pad written in (offer the language they are writing in, English, or any other they name, including a spoken variety such as colloquial Cantonese). Then call the \`${tool}\` tool with their answer; it is remembered for later sessions.`
      : `Summary language: ${language}. Translate the layout's labels into it; keep file names, commands and technical terms as they are. The chat itself stays in the language the person writes in.`,
    '',
    `- File: \`${TASKS}/<task-slug>/${FILE}\` under the working directory, with a short kebab-case English slug. Create it when the task starts, before the first question, and always with the Write or Edit tool: the pane shows only a summary written that way in this session. A quick question or a one-step request is not a task: it gets no file.`,
    '- After every answer, rewrite the whole file so it reads as the current understanding: a running summary, not a question-and-answer log. Short bullets, one line each.',
    '- Rewrite it again at every change of stage: when the plan is set, when a step starts or finishes, when you start waiting on the person or on another agent, when you check a result, when a decision changes, and when the task ends.',
    '- Ask clarifying questions one at a time.',
    '',
    'Layout (leave out an empty section, except the last):',
    '',
    '```markdown',
    '# Task summary: <task name>',
    '',
    '**Status:** Clarifying | Planning | In progress | Waiting | Checking | Done',
    '',
    '## Goal',
    '## Confirmed',
    '## Plan',
    '- [x] <a finished step>',
    '- [~] <the step in progress>',
    '- [ ] <a step not started>',
    '## Done',
    '## Open',
    '',
    LATEST,
    '## Latest',
    '**Q:** <the last question asked, one line>',
    '**A:** <the answer, one line>',
    '```',
    '',
    'Plan lists the steps of the work in order, one line each, with its mark kept as written. When other agents do the steps, name who has each one. Done holds results, not steps: what now exists or was verified.',
    '',
    `Keep the \`${LATEST}\` line exactly as written, untranslated, directly above the last section: the pane finds that section by it. The last section holds only the single most recent thing: the last question and its answer while clarifying, or, once work has started, one \`**Now:**\` line saying what just happened or what is being waited for.`,
    '',
    'The pad only records. If a skill such as skill-creator is running, its process decides what to ask and do.',
  ].join('\n')

export const register: Register = on => {
  // What the pane last drew: a change of file or of its time redraws it.
  let drawn = ''
  let tool = `mcp__pad__${SET_LANGUAGE}`

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: COMMAND,
      description:
        'Turn on the pad: a side pane with a running summary of the task and its progress',
      argumentHint: '[off | language <name>]',
    })
    const registered = await $.tool.register({
      name: SET_LANGUAGE,
      description:
        "Remember the language the person wants their pad (running task summary) written in. Call it once, after asking them, with their answer exactly as they gave it, for example 'English' or 'colloquial Cantonese in Traditional Chinese characters'.",
      inputSchema: {
        type: 'object',
        properties: { language: { type: 'string' } },
        required: ['language'],
      },
    })
    tool = registered.tool
    $.clock.every(POLL_MS, () => {
      void current($).then(summary => {
        const now = summary ? `${summary.path}@${summary.mtimeMs}` : ''
        if (now !== drawn) $.ui.invalidate('ui.render')
      })
    })
    // A reload mid-session: the pane comes back if the pad was on.
    if (await read($, isActive)) void $.ui.open(OPEN).catch(() => undefined)

    return next(e)
  })

  on('command.run', { command: COMMAND }, async ($, e) => {
    const args = e.args.trim()
    if (args === 'off') {
      await update($, isActive, () => false)
      await $.ui.close({ id: PANE })

      return { text: 'Pad off.' }
    }
    const named = /^language\s+(.+)$/i.exec(args)?.[1]?.trim()
    if (named !== undefined) {
      await $.store.set(LANGUAGE, named)

      return { text: `Pad language set to ${named}.` }
    }
    const text = await turnOn($, tool)
    const language = await languageOf($)

    return {
      text:
        language === ''
          ? 'Pad on. You will be asked your summary language once.'
          : `Pad on (${language}).`,
      context: [text],
    }
  }).catch(() => ({ text: 'The pad could not be turned on here.' }))

  // The session writes a summary: that one is what the pane shows from now on.
  on('tool.call', { tool: 'Write' }, async ($, e, next) => {
    const ran = await next(e)
    await noteWrite($, e.file_path, ran).catch(() => undefined)

    return ran
  })

  on('tool.call', { tool: 'Edit' }, async ($, e, next) => {
    const ran = await next(e)
    await noteWrite($, e.file_path, ran).catch(() => undefined)

    return ran
  })

  // skill-creator starts, called by the model: the pad comes on, and its
  // rule reaches the model as a note after the skill's own text.
  on('tool.call', { tool: 'Skill' }, async ($, e, next) => {
    const ran = await next(e)
    if (ran.deny !== undefined || !SKILL_CREATOR.test(e.skill)) return ran
    const text = await turnOn($, tool)

    return { ...ran, context: [...(ran.context ?? []), text] }
  })

  // The same when the person types it as a slash command: the rule enters
  // beside their prompt.
  on('prompt.submit', async ($, e, next) => {
    if (!TYPED_SKILL_CREATOR.test(e.text)) return next(e)
    const text = await turnOn($, tool)

    return next({ ...e, context: [...(e.context ?? []), text] })
  })

  on('tool.call', { tool: 'mcp__pad__set_language' }, async ($, e) => {
    const given = (e as { language?: unknown }).language
    const language = typeof given === 'string' ? given.trim() : ''
    if (language === '') return { result: 'No language was given.' }
    await $.store.set(LANGUAGE, language)

    return {
      result: `Remembered: the pad is written in ${language}. Use it from now on.`,
    }
  }).catch(() => ({ result: 'The language could not be saved.' }))

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Markdown } = $.ui.resolve(e)
    const summary = await current($)
    const text = summary
      ? await $.fs.read(summary.path).catch(() => undefined)
      : undefined
    drawn = summary ? `${summary.path}@${summary.mtimeMs}` : ''

    if (summary === undefined || text === undefined) {
      return (
        <Box flexDirection="column">
          <Text dimColor>No task summary yet.</Text>
          <Text dimColor>
            It shows here once {TASKS}/&lt;task&gt;/{FILE} exists.
          </Text>
        </Box>
      )
    }
    const { body, latest } = split(text)

    return (
      <Box flexDirection="column">
        <Text dimColor>{summary.task}</Text>
        <Markdown text={body} />
        {latest !== '' && (
          <Box flexDirection="column" borderStyle="round" marginTop={1} paddingX={1}>
            <Markdown text={latest} />
          </Box>
        )}
      </Box>
    )
  })
}
