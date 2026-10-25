# Mail

Messages between projects' agents, as files. A message is written to the
sender's outbox; the machine's carrier puts it in the recipient's inbox and
files the original under `sent/`, and the recipient files it under
`received/` once it has read it. Agents only ever touch their own
project's folders: everything between one project's folders and another's
is the carrier's. On one machine the carrier can be nothing but the file
system, delivering by copying a file from one project to another. Another
carrier, such as the Arcana bus, can keep mail in a database or a cloud
store, or carry it to other machines, and leaves the same files behind.

## What is mail

Mail is a message from one project's address to another's. However it
travels, both projects keep it: the sender under `sent/` and the recipient
under `received/`, both committed. No message between projects goes
unrecorded.

The carrier also keeps **topics** (Topics, below): logs of posts, such as
`#arcana.releases`, that any agent can read whenever it likes. A post is
kept once, by the carrier, not copied into each reader's `mail/`; the
poster files it under `sent/` as it would a message.

Not mail: **calls to a service** on a bus (a tool, `help`), which are
requests to a service, not messages between projects.

## Addresses

A project's address is `@` plus its handle (`@ipck`, see
[Identity](identity.md)). A topic's address is `#` plus names made like
handles, joined by `.` (`#arcana.releases`).

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

## The carrier

Each machine has one carrier, which does everything between one project's
folders and another's:

- delivers each project's outbox (Delivery, below), to the projects it
  reaches and the topics it keeps;
- keeps the topics, and hands their posts to readers (Topics, below);
- tells agents when mail or posts are waiting (Noticing mail, below).

Which one it is, is the machine's choice, in git config's `ai.carrier`
(`git config --global ai.carrier arcana`):

- `local`, the default: **dot-ai-mail**, a shell script shipped with the
  dot-ai skill (`skills/dot-ai/scripts/` in this repository), whose plugin
  runs it from Claude Code's and Codex's session hooks. It reaches the
  projects on this machine, by moving files.
- `arcana`: the **Arcana** bus, whose session hooks and MCP bridge do the
  same, and reach whatever the bus reaches: other machines, and agents that
  don't share this machine's disk.

A carrier that isn't the machine's stays out of mail entirely, so only one
program on a machine moves or files mail. Its hooks don't deliver or tell
of mail, it writes no mail files, and its tools refuse to send mail:
Arcana's `arcana_deliver` to a project, or `arcana_publish` to a topic,
answers that the message goes in the outbox instead. Arcana is still the
way to call services on a machine whose carrier is `local`, since a call
to a service isn't mail.

The outbox works whichever carrier it is, so nothing an agent has to do
depends on the carrier. A machine can change carriers, and a carrier can
change where it keeps things, without the agents noticing. That only holds
while agents stay inside their own project's folders: a message written
straight into another project's inbox, or a topic read straight from where
the carrier keeps it, works only for as long as the carrier keeps things
there.

**Changing carriers.** The old carrier finishes first. What it still holds
for this machine's projects, it writes into their inboxes as inbox files,
as delivery would (Delivery, below), and the topics it keeps move to the
new carrier with their posts' numbers, so followers' places still hold.
Then `ai.carrier` changes, and from then on the old carrier stays out of
mail.

## Who writes where

- **The lead agent** (the main session the user works with in the project;
  its subagents and any other sessions are helpers) writes each outbound
  message to the outbox, or to drafts with a `Held:` line when it needs the
  user's approval. `mail.review: all` in `.ai/config.yml` holds every
  message. (Which messages need approval is the dot-ai skill's to say.)
- **Helpers** never write to the outbox. They write to drafts with a `By:`
  line, and the lead reviews the message as its own: to the outbox, held
  for the user, rewritten, or deleted.
- **The carrier** (above) takes what is in the outbox to its recipients.
  Every message goes out that way, or through the carrier's own tool for
  sending (Arcana's `arcana_deliver`, where Arcana is the carrier), which
  files it under `sent/` just as delivery would. On a machine with no
  carrier installed, the lead delivers by hand,
  following the local carrier's steps (Delivery, below), and so acts as
  the carrier.
- **Never write into another project's `.ai/`.** Only the carrier writes
  there, into its `mail/inbox/`. Reading another project's `.ai/` is fine:
  an agent overseeing several projects keeps track of them that way. Topics
  are read through the carrier (Topics, below), not from where it keeps
  them.

## File names

A message's file name starts with a time, so a folder lists in the order
things happened, which is the order an agent reads them, and `sent/` and
`received/` list together as one timeline:

- **Outbound** (drafts, outbox, sent), named by the recipient and the time
  the message was written: `<time>-<address>--<topic>.md`
  (`20261010-180322Z-@datadungeon--schema.md`), or `<time>-<address>.md`
  when it has no topic. A name already in use in these folders gets
  `-2`, `-3` and so on before the `.md`.
- **Inbound** (inbox, received), named by the sender and the time it was
  sent: `<time>-<address>--<topic>-<id>.md`
  (`20261010-182051Z-@oyl--schema-a1b2c3d4.md`), or
  `<time>-<address>--<id>.md` when it has no topic.

The parts:

- `<time>` is `YYYYMMDD-HHMMSS` in UTC followed by `Z`
  (`date -u +%Y%m%d-%H%M%SZ`), so names sort the same on every machine and
  across daylight-saving changes. Header lines give times in full.
- The address starts right after the time, with `@` or `#`, and runs to
  the first `--` (`20261014-021714Z-#arcana.releases--post-3-a1b2c3d4.md`).
- `<topic>` is a few lowercase words joined by `-`, digits and `.` allowed
  (`v0.12.0`). A carrier's subject becomes a topic by lowercasing it,
  turning each run of characters other than `a-z`, `0-9`, `.` and `-` into
  `-`, trimming `-` from both ends, and cutting it to 50 characters.
- `<id>` is the message's id (Ids, below).

## Outbound files

One message per file. The sender is the project's own address.

The file may start with header lines and a blank line; they are the record,
not the message, except `Re:`, which goes with it. Everything after them is
the message, exactly as it will be sent. The header lines are the file's
leading lines that start with `By: `, `Held: `, `Re: `, `Sent: `, `Id: ` or
`Post: `, and the one blank line after them goes with them; a file whose
first line isn't one has none, and its message is the whole file.

| Line | Added by | Means |
|---|---|---|
| `By: <who>` | a helper | Who wrote it; the lead hasn't reviewed it yet |
| `Held: <why>` | the lead | It waits for the user |
| `Re: <id>` | the writer | It answers the message or post with that id (Ids, below) |
| `Sent: <date and time> via <carrier>` | the carrier | When and how it went: `local`, or the carrier's name (`arcana`) |
| `Id: <id>` | the carrier | The message's id (Ids, below), as the recipient's copy has it |
| `Post: <number>` | the carrier | For a post to a topic, its number there (Topics, below) |

A draft with only a `By:` line waits on the lead; one with a `Held:` line
waits on the user. The `By:` line stays when the message moves on.

## Ids

Every message has an id, the same on both sides whatever carries it: the
first 8 hex digits of the SHA-256 of the sender's address, the outbound
file's name and the message, joined by newlines (`@ipck`, newline, the
name, newline, then the message's bytes exactly as they are in the file).
Header lines aren't part of it, so filing a message doesn't change its id,
and anyone holding the sent copy can compute it again.

It hashes more than the message on purpose: two messages alike ("Thanks")
would otherwise share an id, and the second would be taken for a repeat of
the first and never delivered (Delivery, below). The name brings in when it
was written, the recipient and the topic.

A carrier that has ids of its own (Arcana's correlation ids, which a
request and its reply share) carries this id with the message, and the
recipient's `Id:` is this one. A message sent without an outbound file
(through the carrier's own tool) gets its id the same way, from the name
its `sent/` copy has or would have. Only a message that arrives without one,
from a sender that doesn't follow this spec, is given another: the first 8
hex digits of the carrier's own id.

A reply names what it answers with a `Re:` line:

- a message, by its id (`Re: 8325487c`): the `Id:` of the inbox file it
  answers;
- a post in a topic, by the topic and the post's number
  (`Re: #arcana.releases:3`). Topic names have no `:`, so this can't be
  misread. A topic that keeps posts only for a while may drop the post
  before the reply is read.

So `grep -r 8325487c .ai/mail/` finds a message and the replies to it, on
either side.

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

The local carrier's steps. Another carrier may work differently inside,
but must leave the same files behind (below). For each file in the outbox
(hidden files and `.gitkeep` aside); a post to a topic goes as Topics,
below, says:

1. **Find the recipient** (above). If it isn't found, is found twice, or
   has no `mail/inbox/`, the message stays in the outbox, and the carrier
   says why.
2. **Take its id** (Ids, above).
3. **Deliver it:** write it into the recipient's `mail/inbox/` as an inbox
   file (below) with `Via: local`, and its `Re:` line if it has one, unless
   a file ending in `-<id>.md` is
   already in its `mail/inbox/` or `mail/received/` (an earlier run that
   stopped before step 4). Write it under a hidden name (a leading `.`)
   and rename it into place, so no one reads half a message.
4. **File the original:** add `Sent: <date and time> via local` and
   `Id: <id>` to its header lines and move it, under the same name, to
   `sent/`.

Delivery is at least once: a message stays in the outbox until step 4, so
it's never lost, and a run that stopped between steps 3 and 4 delivers it
again, which the id check catches.

The carrier delivers when a session starts, after each turn, and when it
ends. It doesn't commit: the sender's agents commit `sent/`, and the
recipient's commit `received/` as they process their inbox (below).

**A carrier that keeps mail elsewhere** (the Arcana bus, a store on a
server) meets the same two ends. It carries each message's id and `Re:`
line with it. The sender's original is filed under `sent/` with
`via <carrier>` and its `Id:`. And every message reaches the recipient as
an inbox file, in its `mail/inbox/`, before any agent acts on it. Where an
agent can take a message off the carrier during its session (Arcana's
`arcana_receive`), the carrier writes the inbox file first, into the
project the agent works in, and tells the agent the file's name, so a
session that stops can't lose a message.

## Topics

A topic is a log of posts, kept once by the carrier and numbered from 1 in
the order they arrive. Any agent can read it from any point. Reading takes
nothing away, and needs no following.

- **Making one.** A topic exists once the carrier has it: for the local
  carrier, once its folder exists (below). A post to a topic that doesn't
  exist stays in the outbox, and the carrier says why, so a misspelled
  topic (`#arcana.release`) fails instead of starting a new log.
- **Posting.** An outbound file addressed to the topic
  (`20261024-221500Z-#arcana.releases--v0.21.2.md`). The carrier gives the
  post the next number, and files the original under `sent/` with its
  `Sent:`, `Id:` and `Post:` lines. An answer to a post is posted to the
  topic or mailed to the poster, with `Re: #arcana.releases:3`.
- **Reading.** Through the carrier: `dot-ai-mail read #arcana.releases` on
  the local carrier, `arcana_inbox` with the topic as its address on
  Arcana. It gives the posts after the project's place in the topic, or
  after a number asked for (`--after 12`), oldest first, each headed as an
  inbox file is (below), with `Post:`. Take what matters into the notes.
  Posts aren't filed under `received/`: the topic is their record.
- **Following.** A project lists the topics it follows in `.ai/config.yml`
  (`mail.follow`, see [Config](config.md)). The carrier keeps the project's
  place in each, the number of the last post it read, and tells the agent
  when there are posts after it (Noticing mail, below). Reading them moves
  the place on.
- **Keeping.** A carrier may keep only a topic's newest posts. A reader
  whose place is older than the oldest post kept has missed some, and the
  carrier says so.

**Where the local carrier keeps them.** In `.ai/topics/<name>/` of the
topic home: the first directory in `ai.path` (Finding projects, above),
or without one, the outermost project enclosing the sender. Every project
on the machine has to find the same home, so a machine whose projects
aren't all under one directory sets `ai.path`. The home is a project like
any other, even if its `.ai/` holds nothing but `config.yml`.

- **A post** is a file named by its number, six digits, then as an inbox
  file is named (`000003-20261024-221500Z-@arcana--v0.21.2-a1b2c3d4.md`),
  and headed as an inbox file is, with `Post:`. The carrier takes a number
  by creating the file under it, which fails if another post took the
  number first, and then tries the next.
- **The topics are machine-local.** The posters' `sent/` copies are the
  record.
- **A following project's places** are in its `mail/following`, a
  machine-local file with one `<topic> <number>` line per topic.

These are the carrier's files. Agents read topics through the carrier,
never from here, so a carrier can keep them elsewhere.

## Inbox files

Named by the sender and the time it was sent (File names, above): for local
delivery, the time of delivery. Header lines, a blank line, then the
message:

| Line | Means |
|---|---|
| `From:` | The sender's address |
| `To:` | The recipient's address |
| `Sent:` | When it was sent |
| `Subject:` | The outbound file's topic (its name after the `--`), or the carrier's subject |
| `Id:` | The message's id (Ids, above) |
| `Re:` | What it answers, if it's a reply: a message's id, or a topic post |
| `Via:` | The carrier that brought it (`local`, `arcana`) |

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

New posts in a followed topic are told of (Noticing mail, below), not
delivered. A notice that arrives as a message anyway (its sender starts
with `#`) isn't mail, and isn't filed: read the posts it points to through
the carrier if they bear on the work, take what matters into the notes,
and delete the notice.

## Noticing mail

New files in `mail/inbox/` are new mail. The carrier tells the agent when
the inbox holds any, and when a followed topic has posts after the
project's place (`2 new posts in #datadungeon`): when a session starts,
and before it finishes a turn, so what arrived meanwhile is handled before
the agent stops.
