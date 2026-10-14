# dot-ai-mail

*Draft, 2026-10-14. Not built yet.*

A small program that does what [Mail](../spec/mail.md) asks of a delivery
tool: it delivers each project's outbox on this machine and tells agents
when mail is waiting, so the lead no longer delivers by hand. It needs no
server and nothing beyond the file system, and it doesn't need Arcana.

## Form

- **One POSIX `sh` script**, `skill/scripts/dot-ai-mail`, shipped inside
  the skill: installing the skill installs it. `just install` also copies
  it to `~/.local/bin/`, so hooks and people can call it by name. Nothing
  to compile; it runs the same on Linux and macOS.
- **Needs** `find`, `sed`, `date`, `mv`, `git` (for `ai.path`), and one of
  `sha256sum`, `shasum -a 256` or `openssl dgst -sha256`.
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

- **`session-start`:** deliver, then add to the agent's context how many
  messages wait in `.ai/mail/inbox/` (oldest first, by name), and any left
  in the outbox with the reason.
- **`stop`** (every time the agent would finish a turn): deliver, then, if
  the inbox holds files this session hasn't been told of, keep the agent
  going once to process them (Claude: exit 2 with a line on stderr;
  Codex: `decision: block`). The names already told of are kept in
  `$XDG_RUNTIME_DIR/dot-ai-mail/<session id>` (or under `$TMPDIR`), so a
  message the agent leaves for later never loops it.
- A hook never stops a session: anything that goes wrong is one line of
  output and exit 0. It reads `session_id` and `stop_hook_active` from the
  hook's JSON with `sed` (flat fields; no `jq`).

## Delivering

The spec's four steps, with these details:

- **Finding projects** exactly as the spec says: `ai.path`, else the
  outermost enclosing project, else the parent directory; `find` to 4
  levels, pruning hidden directories and `node_modules`, without `-L`.
- **Outbox names:** the address runs from after the time to the first
  `--`. One that starts with `#` stays put ("topics aren't mail").
- **The message** for the id is everything after the header lines and the
  blank line. Header lines are leading lines starting `By: `, `Held: ` or
  `Sent: `; a file whose first line isn't one has none. (The spec should
  say this too, so every deliverer computes the same id.)
- **Filing** writes the original, with `Sent: <time> via local` added to
  its header lines, to `sent/.<name>`, renames it into place, then removes
  the outbox copy. A run that stops between steps finds the message again
  next time, sees its id in the recipient's inbox or `received/`, and only
  files it.
- **No lock.** Two sessions delivering the same outbox at once write the
  same inbox file under the same name, and the second `mv` to `sent/`
  finds nothing to move. The id check covers it.
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
  Arcana the bus mailbox, dot-ai-mail the inbox folder. Both can keep the
  agent going at Stop, and each does so only once for the same mail, so
  they can't push each other into a loop.
- **Later, one place:** once `arcana_receive` writes inbox files (asked of
  @arcana 2026-10-14), Arcana could also move bus mail into the inbox at
  Stop, not only at session end. Then every message would reach agents as
  a file in one folder, and only dot-ai-mail would need to announce mail.
  That's Arcana's call.

## Copious

A copious session is the "tool that runs agents" the spec mentions: its
dotai plugin can call `dot-ai-mail deliver` at session start and end, or
do the same steps itself in Crystal. Either way the ids must match, which
is why the spec should pin down the header lines.

## Not in the first version

- Carrying mail over Arcana itself: Arcana has no send command for a
  script, so the lead sends with `arcana_deliver`.
- Mail between machines without a bus (an open question in the README).
- Windows.
