# dot-ai-mail

*Draft, 2026-10-14; updated 2026-10-19. Built 2026-10-15: `skills/dot-ai/scripts/dot-ai-mail`
0.1.0; 0.2.0 (2026-10-17) adds `Re:` and `Id:`. Tested by `tests/dot-ai-mail.sh` (`just test`); its hooks ship in
the dot-ai plugin (`hooks/hooks.json`).*

A small program that does what [Mail](../spec/mail.md) asks of a delivery
tool: it delivers each project's outbox on this machine and tells agents
when mail is waiting, so the lead no longer delivers by hand. It needs no
server and nothing beyond the file system, and it doesn't need Arcana.

## Form

- **One POSIX `sh` script**, `skills/dot-ai/scripts/dot-ai-mail`, shipped
  inside the skill, and its hooks in the dot-ai plugin: installing the
  plugin installs both, in Claude Code and Codex alike. The hooks run it
  by its path in the plugin (`${CLAUDE_PLUGIN_ROOT}`, which Codex sets
  too), and the skill tells agents that path. Nothing to compile; it's written for Linux and macOS (tested under bash's and
  zsh's sh modes; dash isn't on the machine it was built on).
- **Needs** `find`, `sed`, `awk`, `date`, `mv`, `git` (for `ai.path`),
  and one of `sha256sum`, `shasum -a 256` or `openssl dgst -sha256`.
- **Reads one line of each config:** the top-level `handle:`, written
  plain (`handle: oyl`) or quoted with or without the `@`
  (`handle: "@oyl"`). A config whose handle it can't read that way is
  reported, and that project gets no mail from it. Without a `handle`,
  the directory's name, folded as [Identity](../spec/identity.md) says.

## Commands

| Command | Does |
|---|---|
| `dot-ai-mail deliver [DIR]` | Delivers everything in the outbox of the project at or above `DIR` (default: here). One line per message: delivered, or left in the outbox and why. |
| `dot-ai-mail check [DIR]` | Lists the inbox, oldest first. Exits 1 when it's empty, for scripts. |
| `dot-ai-mail find [ADDRESS]` | Where an address's project is, or every project found with its address: to see why something wasn't delivered. |
| `dot-ai-mail hook EVENT [--agent claude\|codex]` | What the session hooks run (below). The plugin's hooks name no agent: `PLUGIN_ROOT` set means Codex (Claude Code sets only `CLAUDE_*`), else `CLAUDE_PROJECT_DIR` set means Claude Code, else Codex. |
| `dot-ai-mail hooks` | Prints the hook entries to add to Claude Code's and Codex's settings, for use without the plugin. It doesn't edit them: JSON is the one thing `sh` can't safely rewrite. |

## Hooks

- **`session-start`:** deliver, then add to the agent's context everything
  in `.ai/mail/inbox/` (oldest first, by name), any message left in the
  outbox with the reason, and what it delivered.
- **`stop`** (every time the agent would finish a turn): deliver, then, if
  there's anything this session hasn't been told of (new inbox files, a
  message newly left in the outbox, messages it just delivered, which the
  agent should commit), keep the agent going once to deal with it
  (Claude: exit 2 with the text on stderr; Codex: `decision: block`). What
  a session was told of is kept in
  `$XDG_RUNTIME_DIR/dot-ai-mail/<session id>` (or under `$TMPDIR`), so a
  message the agent leaves for later never loops it, and
  `stop_hook_active` isn't needed. Files older than a week are removed.
- **`session-end`:** deliver, quietly.
- A hook never stops a session: anything that goes wrong is one line of
  output and exit 0 (2 only to keep the agent going). It reads
  `session_id` and `cwd` from the hook's JSON with `sed` (flat fields; no
  `jq`), and the project from `CLAUDE_PROJECT_DIR`, else `cwd`.

## Delivering

The spec's four steps, with these details:

- **Finding projects** exactly as the spec says: `ai.path`, else the
  outermost enclosing project, else the parent directory; `find` to 4
  levels, pruning hidden directories and `node_modules`, without `-L`.
- **Outbox names:** the address runs from after the time to the first
  `--`. One that starts with `#` stays put ("topics aren't mail").
- **The message** for the id is everything after the header lines and the
  blank line, byte for byte, as the spec now says (Outbound files).
- **`Re:`** goes to the inbox file as it is, if it names a message's id
  (8 or more hex digits, so an older Arcana id fits too) or a topic's
  post (`#topic:number`); one that names neither stays in the outbox,
  with a reason. Like the other header lines, it isn't part of the id.
- **Filing** writes the original, with `Sent: <time> via local` and
  `Id: <id>` added to its header lines, to `sent/.<name>`, renames it into place, then removes
  the outbox copy. A run that stops between steps finds the message again
  next time, sees its id in the recipient's inbox or `received/`, and only
  files it.
- **A lock per outbox** (`outbox/.delivering`, a directory, so making it
  is atomic). The design had none, but the inbox name carries the time of
  delivery, so two runs a second apart would deliver the same message
  under two names. A run that finds the lock says `busy` and leaves the
  outbox; a lock older than two minutes is a crashed run's, and is cleared.
- **Never commits** (the spec leaves that to the agents).

## With Arcana installed too

They don't overlap: Arcana's hooks never touch the outbox (as of 0.35.3).
They register the handle at session start, nudge the agent at Stop while
the bus has mail for it, and at session end move unread bus mail into
`.ai/mail/inbox/`.

- **Sending:** dot-ai-mail delivers every outbox message whose recipient is
  on this machine; local delivery needs no running session and no server.
  A message whose recipient it can't find stays in the outbox, and its
  hook says so; with Arcana, the lead sends that one over the bus
  (`arcana_deliver`) and files it under `sent/` with `via arcana`. The
  lead never sends by hand a message the tool can deliver. Each message
  goes one way only, and whoever moves it to `sent/` sent it, so the
  recipient never gets it twice.
- **Receiving:** both write inbox files, dot-ai-mail with `Via: local` and
  Arcana with `Via: arcana` (since 0.35.4), under different names. Agents
  process them alike.
- **Noticing:** at session start and at Stop, each reports its own place:
  Arcana the bus mailbox, dot-ai-mail the inbox folder. The two places
  don't overlap, so neither counts a message the other has. Both can keep
  the agent going at Stop, and each does so only once for the same mail
  (Arcana from a fix @arcana made on 2026-10-16; before it, Arcana nudged
  again while bus mail sat unread), so they can't push each other into a
  loop. An agent may hear of mail twice, but never misses any.

@arcana agreed to these three (2026-10-14,
`mail/received/20261014-072229Z-@arcana--…-0983c0fd.md` in ipck's `.ai/`).
Arcana 0.35.4 (`cd9852e`) has `arcana_receive` write the inbox file, so
mail taken live is a file too.

## Decided: dot-ai-mail never calls Arcana

The user decided (2026-10-16, through @arcana: `…-e844c843.md` in ipck's
`.ai/`): dot-ai-mail is light mail for one machine without Arcana, so it
doesn't call Arcana even when Arcana is installed. Each tool announces its
own place, as above, rather than dot-ai-mail being the one voice.
@arcana's earlier proposal for one voice (2026-10-14, `…-51da5b86.md`: an
`arcana hook drain` that dot-ai-mail's Stop hook runs first) was built,
then removed before release. dot-ai stands on its own and
leads on to Arcana, which adds what files can't reach (other machines,
cloud agents, live sessions, services) without changing anything in
`.ai/`. Nor does dot-ai-mail step aside when Arcana is installed: Arcana
would have to re-implement local delivery, and nothing would be delivered
while the bus is down.

## Decided: mail keeps its record

Mail is filed under `sent/` and `received/` even where transcripts are
committed: the user agreed (2026-10-17), after asking whether transcripts
could be the record. Claude Code and Codex commit no transcripts, so for
most projects the mail folders are the only committed copy; each file is
one message, word for word, named by time, peer and topic; and it records
what two projects said to each other, on both sides. Where a runtime
commits transcripts there's no second copy: a Copious agent pins a mail
file with `view`, pinned views aren't persisted, and the transcript keeps
only the call. Since `received/` is never edited, the path is a lasting
reference.

## Decided: a session's project is the nearest `.ai/` above it

@arcana's review (2026-10-16, `…-6d54cbb1.md`) found that dot-ai-mail
walks up to the nearest `.ai/` while Arcana's hooks take a directory
without one as a project of its own, and suggested stopping the walk at
the top of the git repository. The user decided (2026-10-17) that the
walk is right, as [Layout](../spec/layout.md) already said: a directory
without its own `.ai/` belongs to the project above it, whose agent is
responsible for it until the user gives it one. Arcana's hooks and bridge
now walk up the same way (the user, 2026-10-17; arcana 0.35.5, `1cb0528`,
`…-8f32ce65.md`), so both tools find the same project.

## Decided: `arcana_deliver` files the `sent/` copy

The mirror of `arcana_receive` writing the inbox file: an agent can send
over the bus without the outbox, and then nothing reached `sent/`. The
user decided (2026-10-17, `…-19d7c47a.md` in ipck's `.ai/`) that
`arcana_deliver` writes the copy itself (arcana 0.35.5, `0521bc2`, not
released yet), for a message from the project's address to an agent.

## Fixed: a message dot-ai-mail can't place was filed twice

When dot-ai-mail leaves a message in the outbox (its recipient isn't on
this machine), the lead sends it over the bus. Arcana 0.36.0 files its own
copy, and the skill then had the lead move the outbox file to `sent/` as
well, so the message was filed twice under two names. Since 2026-10-19
(plugin 0.3.1) the lead deletes the outbox file once `arcana_deliver`
returns `sent_file`. Arcana's copy is named by the time it was sent, not
the time it was written, and a helper's `By:` line isn't kept. If that
matters, Arcana could send the outbox file itself (`arcana send FILE`, or
a `file` argument), keeping its name and header lines; @arcana offered it.

## Copious

A copious session is the "tool that runs agents" the spec mentions: its
dotai plugin can call `dot-ai-mail deliver` at session start and end, or
do the same steps itself in Crystal. Either way the ids must match, which
is why the spec should pin down the header lines.

## Not in the first version

- Mail between machines without a bus (an open question in the README).
- Windows.
