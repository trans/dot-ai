# Mail, in full

The skill's Mail section is all an agent needs day to day. This is the
rest: how mail works, and what to do when it goes wrong. Read it when a
message is left in the outbox, mail seems lost or doubled, a file or a
header line puzzles you, or the user asks how mail works.

## How it works

Mail is a message from one project's address to another's. Both sides
keep it, committed: the sender under `.ai/mail/sent/`, the recipient under
`.ai/mail/received/`, so no message between projects goes unrecorded.
Neither folder is ever edited. Topics are logs anyone reads, not mail
(Topics, below).

Mail is carried by the machine's **carrier**, one per machine, chosen by
git config's `ai.carrier` (`git config ai.carrier`): unset or `local` is
`dot-ai` itself (`scripts/dot-ai`, which this skill ships); `arcana` is
Arcana (see `references/arcana.md`). Both keep to the same files and locks,
so a change of carrier moves nothing. `dot-ai`'s commands are the same
under either: where Arcana carries the mail, `dot-ai` hands it the
delivering and the topics (`arcana mail`), and Arcana stays out of mail
where `dot-ai` carries it.

Agents write only into their own project's `.ai/mail/`. Only the carrier
writes into another project's `.ai/` or into the topics (or the lead,
delivering by hand where the carrier can't run, below).

Drafts, the outbox and the inbox are machine-local, never committed:
pushed, a message in the outbox could go out twice, once from each
machine.

## The files

An outbound file (drafts, outbox, sent) is named
`<time>-<address>--<topic>.md`, and keeps that name as it moves between
folders. `dot-ai mail send` names and writes it. The time is when it was written, in UTC, so every mail folder
lists in the order things happened. The address runs from the `@` (a
topic's, from the `#`) to the first `--`.

It may start with header lines and a blank line. They are the record, not
the message, except `Re:`, which goes with it:

- `By: <who>`: a helper wrote it; the lead reviews it.
- `Held: <why>`: it waits on the user.
- `Re: <id>` or `Re: #topic:<number>`: what it answers.
- `Sent: <time> via <carrier>`, `Id: <id>`, and for a post `Post:
  <number>`: added on delivery, on the copy under `sent/`.

Everything after them is the message, exactly as it was sent.

An inbox file is named by the time the message was sent, the sender, the
topic and the message's id: `20261010-182051Z-@oyl--schema-a1b2c3d4.md`.
It starts with `From:`, `To:`, `Sent:`, `Subject:`, `Id:`, `Re:` (on a
reply) and `Via:` (the carrier), a blank line, then the message. Anything
the sender attached beyond text follows as a JSON block. A file whose name
starts with `.` is a delivery in progress: leave it.

A message's **id** is the first 8 hex digits of the SHA-256 of the
sender's address, the outbound file's name and the message, joined by
newlines. It is the same on both sides, so a reply's `Re:` finds its
message in either project's folders.

## Delivery

`dot-ai mail deliver` (which `send` runs) takes each message in the outbox to its recipient's
`.ai/mail/inbox/` (a post, to its topic, numbered), then files the
original under `.ai/mail/sent/` with `Sent:` and `Id:` lines (and
`Post:`). It prints a line for each: `delivered:`, `posted:`, or `left in
the outbox:` and why. Installed as a plugin, the skill's session hooks
deliver at the end of each turn and tell you when mail arrives; without
the plugin, `dot-ai hooks` prints them to add by hand.

### When a message is left in the outbox

Leave it there, never send it another way (Arcana's `arcana_deliver`
included), and never delete it. Fix what's yours to fix; otherwise tell
the user the reason.

| It says | What to do |
|---|---|
| no project on this machine has the address @x | Check the address with `dot-ai mail find` (every project) or `dot-ai mail find x`. If it's misspelt, rename the file. Otherwise tell the user: the project may have no `.ai/`, or sit outside `ai.path`. |
| two projects have the address @x | Tell the user: two projects' configs give the same handle. |
| @x (DIR) has no .ai/mail/inbox/ | Tell the user: that project's `.ai/` has no mail folders. |
| there's no topic #x | Check the name with `dot-ai mail topic`. If it's misspelt, rename the file; if the topic is yours to make, make it; otherwise ask. |
| its name isn't <time>-<address>--<topic>.md, or X isn't an address | Rename the file (it's yours), then deliver again. |
| its Re: line isn't a message's id or a topic's post | Fix the `Re:` line, then deliver again. |
| couldn't write to DIR/ (from a sandbox, leave it…) | Run inside a sandbox (Codex's), `deliver` can't write into other projects. Leave it: the hooks, which run outside the sandbox, deliver it when the turn ends. |
| busy: another delivery from this outbox is running | Nothing: the next run takes it. |
| error: NAME went to @x, but couldn't be filed under .ai/mail/sent/ | It went: don't send it again. Tell the user. |
| this machine's carrier is X, which dot-ai can't hand mail to | Tell the user: `git config ai.carrier` names a carrier `dot-ai` doesn't know. |
| this machine's carrier is arcana, but there's no arcana command | Tell the user: Arcana isn't installed here, or `ai.carrier` is wrong. |

### Delivering by hand

Only where `dot-ai` can't run at all (no `sh`, as on Windows), the lead
delivers:

1. Find the recipient's project (the skill's Other projects). If it isn't
   found, is found twice, or has no `.ai/mail/inbox/`, leave the message in
   the outbox and tell the user why.
2. Write the message into the recipient's `.ai/mail/inbox/` as an inbox
   file (The files, above) with `Via: local`, and its `Re:` line if it has
   one. If a file ending in `-<id>.md` is already in the recipient's
   `mail/inbox/` or `mail/received/`, it was delivered before: skip to
   step 3.
3. Add `Sent: <date and time> via local` and `Id: <id>` to the original's
   header lines and move it, under the same name, to `.ai/mail/sent/`.

## Receipts

A message has been read once its recipient files it under its
`received/`. The hooks then say so, at the next prompt or session start
(never keeping you going on their own), under "Receipts for mail this
project sent", naming your copy under `sent/`:

- `@oyl read NAME`: read.
- `@oyl took NAME out of its inbox without filing it under received/`.
- `@oyl: no telling whether it read NAME, since its project is no longer
  at DIR`.

To see whether a message was read, wait for its receipt rather than
looking in the recipient's folders. The outbox's hidden `.receipts` is the
carrier's list of messages still waiting for one: leave it alone.

## Topics

A topic is kept once by the carrier, in a folder of its own: never look
in it or write into it, but go through the carrier's commands, so it can
keep topics elsewhere.

- Delivery gives a post the next number and files it under `sent/` with a
  `Post:` line. A post to a topic that doesn't exist stays in the outbox,
  so a misspelling can't start a new log.
- `read '#name'` prints the posts after this project's place in the
  topic, oldest first, and moves the place on; `--after N` gives the posts
  after number N. Where older posts are gone, it says so.
- The place is kept in `.ai/mail/following`, machine-local. If
  `.ai/.gitignore` doesn't list `mail/following` and `topics/` yet, add
  them (as `assets/gitignore` has them) and commit that.
- Posts aren't filed under `received/`: the topic is their record.
- Refer to a post as `#name:N`, and answer one with `Re: #name:N`.

## Files from topics and the Arcana bus

- **A notice from a topic** (an inbox file whose sender starts with `#`)
  came from a topic on the Arcana bus that this project subscribed to
  there. It isn't mail and is never filed: read the post it points to if
  it bears on the work, take what matters into the notes, and
  `dot-ai mail done` removes the notice.
- **Mail from the Arcana bus** (`Via: arcana`), sent there before Arcana
  stopped carrying mail on this machine, is put in the inbox by Arcana's
  hooks: process it like any other.

## Mail that seems lost or doubled

- **You sent it, and no answer came:** if it's under `sent/` with a
  `Sent:` line, it was delivered. Its receipt says when it's read.
- **It's still in the outbox:** see the table above, or deliver again.
- **Two inbox files with the same id** are one message that came twice
  (by two carriers, say): process one and delete the other.
- **A file named `.<something>`** in the inbox, outbox or sent is a write
  in progress, or one a crash left: leave it, and tell the user if it
  stays.
