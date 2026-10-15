# dot-ai-mail

*Draft, 2026-10-14. Built 2026-10-15: `skill/scripts/dot-ai-mail` 0.1.0,
tested by `tests/dot-ai-mail.sh` (`just test`).*

A small program that does what [Mail](../spec/mail.md) asks of a delivery
tool: it delivers each project's outbox on this machine and tells agents
when mail is waiting, so the lead no longer delivers by hand. It needs no
server and nothing beyond the file system, and it doesn't need Arcana.

## Form

- **One POSIX `sh` script**, `skill/scripts/dot-ai-mail`, shipped inside
  the skill: installing the skill installs it. `just install` also copies
  it to `~/.local/bin/`, so hooks and people can call it by name. Nothing
  to compile; it's written for Linux and macOS (tested under bash's and
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
| `dot-ai-mail hook EVENT [--agent claude\|codex]` | What the session hooks run (below). |
| `dot-ai-mail hooks` | Prints the hook entries to add to Claude Code's and Codex's settings. It doesn't edit them: JSON is the one thing `sh` can't safely rewrite. |

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
- **Filing** writes the original, with `Sent: <time> via local` added to
  its header lines, to `sent/.<name>`, renames it into place, then removes
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
  Arcana with `Via: arcana, …`, under different names. Agents process them
  alike.
- **Noticing:** at session start and at Stop, each reports its own place:
  Arcana the bus mailbox, dot-ai-mail the inbox folder. The two places
  don't overlap, so neither counts a message the other has. Both can keep
  the agent going at Stop, and each does so only once for the same mail,
  so they can't push each other into a loop.

@arcana agreed to these three (2026-10-14,
`mail/received/20261014-072229Z-@arcana--…-0983c0fd.md` in ipck's `.ai/`).
Arcana 0.35.4 (`cd9852e`) has `arcana_receive` write the inbox file, so
mail taken live is a file too.

## Later: one voice

The user is still deciding (2026-10-14). The idea: dot-ai stands on its own
because it needs nothing installed, and leads on to Arcana, which adds what
files can't reach (other machines, cloud agents, live sessions, services)
without changing anything in `.ai/`. @arcana's proposal for that step
(2026-10-14, `…-51da5b86.md`):

- **dot-ai-mail is the one voice.** It announces mail; Arcana's Stop hook
  is left out. Arcana won't move bus mail into the inbox from its own Stop
  hook: Claude Code runs one event's hooks in parallel, so dot-ai-mail
  could scan the inbox before Arcana's files land, and the agent would stop
  without hearing of them. Instead Arcana adds a command (`arcana hook
  drain`, say) that writes waiting bus mail into the inbox and prints the
  files; dot-ai-mail's Stop hook runs it first when `arcana` is installed.
- **Arcana sends what dot-ai-mail can't place,** and files it under
  `sent/` with `via arcana`, so the lead no longer sends by hand.
- **The upgrade shows itself:** a message dot-ai-mail can't place says so,
  and that Arcana could deliver it ("@x isn't on this machine").
- **No draining where the inbox won't last** (a cloud container): the bus
  keeps unread mail, and `arcana_receive` writes the file when it's read.
- dot-ai-mail stays tiny; anything complicated belongs in Arcana.

Nothing is scheduled on Arcana's side until the user decides.

## Copious

A copious session is the "tool that runs agents" the spec mentions: its
dotai plugin can call `dot-ai-mail deliver` at session start and end, or
do the same steps itself in Crystal. Either way the ids must match, which
is why the spec should pin down the header lines.

## Not in the first version

- Carrying mail over Arcana itself: Arcana has no send command for a
  script yet, so the lead sends with `arcana_deliver` (see Later: one
  voice).
- Mail between machines without a bus (an open question in the README).
- Windows.
