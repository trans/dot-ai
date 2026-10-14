# Mail

Messages between projects' agents, as files. A message is written to the
sender's outbox; delivery puts it in the recipient's inbox and files the
original under `sent/`, and the recipient files it under `received/` once
it has read it. All of it works with nothing but the file system:
on one machine, delivering is copying a file from one project to another.
Other transports, such as the Arcana bus, can carry mail further or live,
and leave the same files behind.

## Addresses

A project's address is `@` plus its handle (`@ipck`, see
[Identity](identity.md)). Mail goes from one project's agents to another's.

## The folders

| Folder | Holds | Committed |
|---|---|---|
| `mail/drafts/` | Outbound messages waiting for review: by the lead agent, or by the user | no |
| `mail/outbox/` | Outbound messages cleared to go | no |
| `mail/sent/` | Every message sent, never edited: the record of exactly what was said | yes |
| `mail/inbox/` | Messages that arrived, not yet processed | no |
| `mail/received/` | Every message processed, never edited: the record of exactly what was heard | yes |

Drafts, the outbox and the inbox are machine-local. Pushed, a message in the
outbox could go out twice, once from each machine. A message that arrives
is committed once it has been read, under `received/`, so the inbox holds
only what this machine's agents haven't dealt with yet. A message keeps its
file name as it moves from folder to folder.

A project receives mail once it has `mail/inbox/`; one with `.ai/` but no
`mail/` hasn't set up mail.

## Who writes where

- **The lead agent** (the main session the user works with in the project;
  its subagents and any other sessions are helpers) writes each outbound
  message to the outbox, or to drafts with a `Held:` line when it needs the
  user's approval. `mail.review: all` in `.ai/config.yml` holds every
  message. (Which messages need approval is the dot-ai skill's to say.)
- **Helpers** never write to the outbox. They write to drafts with a `By:`
  line, and the lead reviews the message as its own: to the outbox, held
  for the user, rewritten, or deleted.
- **Delivery** (below) takes what is in the outbox to its recipients. Until
  a delivery tool runs on the machine, the lead delivers by hand, following
  the same steps.
- **Never write into another project's `.ai/`,** except to deliver into its
  `mail/inbox/`. Reading another project's `.ai/` is fine: an agent
  overseeing several projects keeps track of them that way.

## File names

A message's file name starts with a time, so a folder lists in the order
things happened, which is the order an agent reads them, and `sent/` and
`received/` list together as one timeline:

- **Outbound** (drafts, outbox, sent), named by the recipient and the time
  the message was written: `<time>-<address>--<topic>.md`
  (`20261010-180322Z-@datadungeon--schema.md`).
- **Inbound** (inbox, received), named by the sender and the time it was
  sent: `<time>-<address>--<topic>-<id>.md`
  (`20261010-182051Z-@oyl--schema-a1b2c3d4.md`), or
  `<time>-<address>--<id>.md` when it has no topic.

The parts:

- `<time>` is `YYYYMMDD-HHMMSS` in UTC followed by `Z`
  (`date -u +%Y%m%d-%H%M%SZ`), so names sort the same on every machine and
  across daylight-saving changes. Header lines give times in full.
- The address runs from the `@` after the time to the first `--`.
- `<topic>` is a few lowercase words joined by `-`, digits and `.` allowed
  (`v0.12.0`). A transport's subject becomes a topic by lowercasing it,
  turning each run of characters other than `a-z`, `0-9`, `.` and `-` into
  `-`, trimming `-` from both ends, and cutting it to 50 characters.
- `<id>` is the message's id (Delivery, below).

## Outbound files

One message per file. The sender is the project's own address.

The file may start with header lines and a blank line; they are the record,
not the message. Everything after them is the message, exactly as it will be
sent.

| Line | Added by | Means |
|---|---|---|
| `By: <who>` | a helper | Who wrote it; the lead hasn't reviewed it yet |
| `Held: <why>` | the lead | It waits for the user |
| `Sent: <date and time> via <transport>` | delivery | When and how it went: `local`, or another transport's name (`arcana`) |

A draft with only a `By:` line waits on the lead; one with a `Held:` line
waits on the user. The `By:` line stays when the message moves on.

## Finding projects

Delivery finds a recipient by searching this machine for `.ai/`
directories. Nothing registers: a project is wherever its `.ai/` is, and
its address comes from its own config, so a project that moves is found
where it is now.

- **Where to search:** the directories in git config's `ai.path`, a
  multi-valued key (`git config --global --add ai.path ~/Projects`; read
  with `git config --get-all --type=path ai.path`, which expands `~`).
  Without any, the outermost project enclosing the sender (its nearest
  ancestor directory with `.ai/`, then that one's, and so on), or, if no
  project encloses it, the sender's parent directory.
- **What counts:** a directory holding `.ai/` is a project, a search root
  included. The search goes on below a project, since a project may hold
  others (see [Layout](layout.md)). It doesn't descend into `.ai/` itself,
  hidden directories or `node_modules/`, nor more than 4 levels below a
  search root.
- **Symbolic links aren't followed,** so each project is found once, where
  it really is.
- **Addresses** come from each project's `handle` in its `.ai/config.yml`,
  or its directory's name without one (see [Identity](identity.md)).
- **Two projects with one address** is an error: nothing is delivered to
  that address, and the tool names both directories.

A tool may keep what a search found for the length of a run, but must check
that a project is still where it was (its config still gives that address)
before writing to it.

## Delivery

For each file in the outbox (hidden files and `.gitkeep` aside):

1. **Find the recipient** (above). If it isn't found, is found twice, or
   has no `mail/inbox/`, the message stays in the outbox, and the tool says
   why.
2. **Take its id:** the first 8 hex digits of the SHA-256 of the sender's
   address, the outbound file's name and the message, joined by newlines.
   The same message always has the same id.
3. **Deliver it:** write it into the recipient's `mail/inbox/` as an inbox
   file (below) with `Via: local`, unless a file ending in `-<id>.md` is
   already in its `mail/inbox/` or `mail/received/` (an earlier run that
   stopped before step 4). Write it under a hidden name (a leading `.`)
   and rename it into place, so no one reads half a message.
4. **File the original:** add `Sent: <date and time> via local` to its
   header lines and move it, under the same name, to `sent/`.

Delivery is at least once: a message stays in the outbox until step 4, so
it's never lost, and a run that stopped between steps 3 and 4 delivers it
again, which the id check catches.

A delivery tool doesn't commit: the sender's agents commit `sent/`, and the
recipient's commit `received/` as they process their inbox (below). A tool
that runs agents should deliver when a session starts and ends, and an
agent that clears a message to the outbox should have it delivered then.

**Other transports.** Local delivery reaches the projects on this machine.
A delivery tool may carry mail further over another transport, such as the
Arcana bus, to an address it can't find here. Whatever carries a message,
the sender files it under `sent/` with `via <transport>`, and the recipient
ends up with an inbox file (Arcana's session hooks write one for each bus
message still unread when a session ends).

## Inbox files

Named by the sender and the time it was sent (File names, above): for local
delivery, the time of delivery. Header lines, a blank line, then the
message:

| Line | Means |
|---|---|
| `From:` | The sender's address |
| `To:` | The recipient's address |
| `Sent:` | When it was sent |
| `Subject:` | The outbound file's topic (its name after the `--`), or the transport's subject |
| `Id:` | The message's id |
| `Via:` | The transport that brought it (`local`, `arcana`) |

Anything sent beyond text follows the message as a JSON block. A hidden
file in the inbox is a delivery in progress; readers ignore it.

An inbox file has not been dealt with yet. Processing one:

1. Take what matters into the project's notes (see [Memory](memory.md)), in
   the agent's own words. A message to consult again (a spec, a design)
   can be cited by its path in `received/` instead.
2. Move it, unchanged and under the same name, to `received/`.
3. Commit the notes and the message together.

`received/` is never edited: it's the record of exactly what other projects
said. In a public repository, a message with private details is summarized
and deleted instead of filed, so the original is never committed.

## Noticing mail

New files in `mail/inbox/` are new mail. A tool that runs agents should tell
the agent when the inbox holds any: when a session starts, and before it
finishes a turn, so a message that arrived meanwhile is handled before the
agent stops.
