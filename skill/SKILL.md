---
name: dot-ai
description: A project's memory and coordination for AI agents, kept in its .ai/ directory, a git worktree of the project repo's orphan `ai` branch (ignored by the code checkout) - .ai/config.yml (the project's handle, its mail address), notes in .ai/memory indexed by .ai/memory/README.md, mail between projects' agents in .ai/mail (drafts, outbox, sent, inbox, received), session transcripts in .ai/transcript, and intake/ and outtake/ for files passed between the user and agents. Use this skill whenever you start or resume work in a repository that has a .ai/ directory; whenever the user says to remember something, make or update a note, record a decision, plan, status or lesson, or asks where things stand; when they say to check mail or message another project's agent; whenever a file shows up in .ai/mail or intake/; when asked to set up .ai/ in a project or move an existing one onto its own branch. Also use it to decide whether a fact belongs in the project's notes, the project's own docs, or your own per-machine memory.
---

# .ai/: project memory and coordination for agents

A `.ai/` directory holds what AI agents working on a project need that the
code and git history don't say: where things stand, agreed plans, decisions
in progress and their reasons, lessons that cost something to learn, mail
between projects' agents, and session transcripts.

`.ai/` lives on the project repository's **`ai` branch**, an orphan branch
that shares no history with the code, checked out into `.ai/` as a git
worktree. The code checkout ignores `/.ai/`. Notes stay out of the code's
history and its CI (the branch has no workflows), and there is no second
repository to keep: one clone carries both. Pushed, the branch reaches
every agent on every machine, including the next session after a crash.

The branch is as visible as the repository: in a public repo, anyone can
read it. Notes there follow the rule for public repos (see Writing notes),
and transcripts are always redacted before they're committed (see
Transcripts).

**Alternative: a separate repository.** A project may keep `.ai/` in its own
repository instead, cloned into `.ai/` and ignored by the code checkout:
for example, a public project whose notes and transcripts must stay
private without encryption. Everything here applies; the differences are
that a fresh clone takes a second `git clone … .ai`, and you push that
repository's own branch. `git -C .ai remote -v` shows which arrangement a
project uses.

What anyone working on the code should know (settled design, conventions,
how to build) belongs in the project's own docs (README, `CLAUDE.md` or
`AGENTS.md`, a docs or design directory) in the code repo. `.ai/` is the
agents' working space.

## Layout

```
.ai/                a worktree of the repo's `ai` branch
  .gitignore        ignores the contents of mail/drafts, mail/outbox and mail/inbox, and arcana.token
  config.yml        settings agents and tools read: handle, description, mail.review, ...
  arcana.token      Arcana's owner token, if the project uses Arcana; machine-local, never committed
  memory/
    README.md       the index: one row per note, plus the conventions
    <topic>.md      one note per topic: handoff.md, release.md, ...
    <reference>     material kept whole: a spec, a design, a patch
  mail/
    drafts/         outbound messages waiting for review: the lead's, or the user's; machine-local
    outbox/         outbound messages cleared to go, until delivered; machine-local
    sent/           every message sent, committed: the record of what was said
    inbox/          messages from other projects' agents, not yet read; machine-local
    received/       every message read, committed: the record of what was heard
  transcript/       session transcripts, written by agent runtimes (e.g. Copious)
  records/          curated records (notes, summaries, memories), one file each, by user
```

Each `mail/` folder holds a `.gitkeep` so it exists in a fresh checkout.
The code's `.gitignore` lists `/.ai/`.

Next to `.ai/`, in the project's own directory, are two folders for the
user: `intake/`, where the user shares files with you, and `outtake/`, where
you (usually the lead) share files with the user (Intake and outtake,
below). Nothing in them is ever committed.

Run git against the `ai` branch's worktree (`git -C .ai ...`); paths
inside it are relative to `.ai/` (`memory/release.md`, `mail/inbox/<file>`).

## At the start of a session, or on "resume"

1. If `.ai/` is missing but the repo has an `ai` branch (`git branch -r`
   lists `origin/ai`), ask the user whether to check it out:
   `git worktree add .ai ai`. Otherwise bring it up to date
   (`git -C .ai pull --ff-only`); another machine may have pushed.
2. Read `.ai/config.yml` and the memory index, then the notes that bear on
   the task. A status or handoff note is usually where "where were we?"
   starts. The index exists so you don't have to read every note.
3. Look in `.ai/mail/`: process the inbox, and if you are the lead, review
   drafts from helpers and tell the user about drafts waiting for them (all
   below). Look in `intake/` for files the user left for you.
4. If the project uses Arcana (its tools are available, or a session hook
   said it registered you), check the bus too: see `references/arcana.md`.
5. Treat notes as true when written, not necessarily now. Before acting on
   one that names a function, flag, file or commit, check the code or
   `git log`. When a note turns out wrong, fix it.

## Other projects

A project's address is `@` plus `handle` from its `.ai/config.yml`
(`handle: oyl` gives `@oyl`), or, without one, `@` plus its directory's
name. Use addresses as given, never a variant. If this project's config
has no `handle`, suggest one to the user and add it.

Projects are found by searching for `.ai/` directories: under the
directories `git config --get-all --type=path ai.path` lists, or, without
any, under the outermost project enclosing this one (this project's parent
directory, if none encloses it). Look below projects too, since a project
may sit inside another (an overseer that keeps track of the projects below
it), but don't follow symbolic links: each project is found once, where it
really is.

You may read another project's `.ai/` (its status, its notes): that's how
an overseer keeps track. Write to it only by mail.

## Mail

Mail is a message from one project's address to another's, however it
travels: both sides keep it, committed, the sender under `sent/` and the
recipient under `received/`, so no message between projects goes
unrecorded. Arcana topics aren't mail (`references/arcana.md`).

The lead agent (the main session the user works with here; subagents and
other sessions are helpers) writes mail on the user's behalf. For each
message it decides one thing: does this need the user's approval?

- **No:** put it in `.ai/mail/outbox/`, and have it delivered (below).
- **Yes:** put it in `.ai/mail/drafts/` with a first line `Held: <why>`,
  and tell the user. Once they approve, move it to the outbox; if they turn
  it down, delete it.

**Mail from helpers.** A subagent, or another session working on the
project, never sends and never writes to the outbox. It puts its message in
`.ai/mail/drafts/` with a first line `By: <who wrote it>`, and the lead
reviews it as if it had written it: routine mail goes to the outbox (the
`By:` line stays, as the record of who wrote it), mail that needs the user
gets a `Held: <why>` line, and mail that shouldn't go is rewritten or
deleted. So a draft waits on the lead while it has only a `By:` line, and
on the user once it has a `Held:` line.

**What needs approval.** The user can't read every message, so only what
needs them waits. Hold anything that:

- commits the user or the project: a promise, a deadline, agreeing to or
  declining a change another project asked for;
- makes or reverses a decision the user hasn't made;
- pushes back on another agent's plan;
- shares something private, or reaches beyond the agent network (people,
  outside services);
- is of a kind, or to a recipient, the user asked to see first.

Routine mail goes straight out: status updates, notices of things done
("the schema change landed in `abc1234`"), answers from what is already
settled (code, docs, notes), acknowledgements, and requests for
information. When unsure, hold. Under `mail.review: all` in
`.ai/config.yml`, everything is held.

**The files.** One message per file, named by the time you write it and
the recipient's address: `<time>-<address>--<topic>.md`, for example
`20261010-180322Z-@datadungeon--schema.md`. The time is UTC
(`date -u +%Y%m%d-%H%M%SZ`), so every mail folder lists in the order things
happened; the address runs from the `@` to the first `--`; the topic is a
few lowercase words joined by `-`. The file keeps its name as it moves
between folders. It may start with header lines (`By:`, `Held:`, `Sent:`)
and a blank line; they are the record, not the message. Everything after
them is the message exactly as it will be sent. The sender is this
project's address.

**Delivery** takes each message in the outbox to its recipient and files
the original under `.ai/mail/sent/`. If a delivery tool runs on this
machine, leave it to the tool. Otherwise the lead delivers by hand:

1. Find the recipient's project (Other projects, above). If it isn't
   found, is found twice, or has no `.ai/mail/inbox/`, leave the message in
   the outbox and tell the user why.
2. Write the message into the recipient's `.ai/mail/inbox/` as an inbox
   file (Receiving, below) with `Via: local`. Its id is the first 8 hex
   digits of the SHA-256 of this project's address, the outbound file's
   name and the message, joined by newlines. If a file ending in
   `-<id>.md` is already in the recipient's `mail/inbox/` or
   `mail/received/`, it was delivered before: skip to step 3.
3. Add `Sent: <date and time> via local` to the original's header lines
   and move it, under the same name, to `.ai/mail/sent/`.

With Arcana, the bus can carry the message instead (`references/arcana.md`).
`sent/` is committed and never edited: it's the user's record of exactly
what was said. When the user asks what went out, point them there.
Otherwise mention routine mail briefly, by count, and held drafts by name.

**Machine-local:** drafts, the outbox and the inbox aren't committed.
Pushed, a message in the outbox could go out twice, once from each
machine. Mail that arrives is committed once it's read, under
`.ai/mail/received/`.

**Never write into another project's `.ai/`** except to deliver into its
`mail/inbox/`.

**Receiving.** Mail arrives in `.ai/mail/inbox/`: delivered from other
projects' outboxes, or, with Arcana, bus mail still unread when a session
ended. A message you take off the bus yourself goes there too, at once
(`references/arcana.md`). Inbox files are named by the time the message
was sent, the sender, the topic and the message's id
(`20261010-182051Z-@oyl--schema-a1b2c3d4.md`). A sender starting with `#`
is an Arcana topic, a log of posts anyone can read at any time; this
project subscribed to it, so it sends a notice of each new post
(`20261014-021714Z-#arcana.releases--post-3-a1b2c3d4.md`). A notice isn't
mail (Processing the inbox, below).
Inbox files start with header lines (`From:`, `To:`, `Sent:`, `Subject:`,
`Id:`, `Via:`), a blank line, then the message. Anything the sender
attached beyond text follows as a JSON block. A file whose name starts with
`.` is a delivery in progress; leave it.
When the user says "check mail" (agent mail, not email), look here, and on
the bus too if the project uses Arcana.

## Transcripts

The formats below (transcripts, records, ids, protection) are specified in
the dot-ai spec, the user's `dot.ai` repository; this is the working
summary.

`.ai/transcript/` holds session transcripts, written by an agent runtime
such as Copious: the event stream, one entry per event, tagged with its ID
(`<E1043 at="…" by="…">…</E1043>`). Each user numbers their own stream;
a file's header names its user (`handle`, from `users:` in
`.ai/config.yml`) and machine, and another user's entry is referred to as
`E1043@pat`. The runtime writes, commits and pushes them; agents read them
and never edit them. To look up an entry, grep for the start of its tag
(`grep -rn '^<E1043 ' .ai/transcript`), in the files whose header names
the right user. A quoted copy inside a later entry may also match, and the
real one is the entry in its own file.

`.ai/records/<handle>/<YYYY-MM>/` holds the curated records taken from the
transcripts: notes, summaries, memories, citations, and any other kinds a
runtime keeps (Justice's concerns, for one). One file per record (`N3.md`),
front matter (one field per line, its value as JSON) and its text as the
body. A record's id is its code, number and author (`N3@trans`), shown
without the handle to its author. Files are never rewritten: a change is a
new version (`N3.2.md`), a removal a version with `removed: true`. The
runtime's database is only an index of these, rebuilt on any clone.

**Protection.** What is committed is always redacted. The runtime masks
secrets (known secret values, token formats, private keys), and an AI pass
replaces private spans with markers like `[redacted: email]`: contact
details, internal hosts, private files' contents, and with
`transcript.redaction: strict`, names and other people's words too. The
full transcript stays on the machine that wrote it, outside `.ai/`
(Copious keeps it in `.var/ai/transcript/` until it's committed). With
`transcript.encrypt: true` in `.ai/config.yml`, the redacted transcripts are
also encrypted on the branch with git-crypt (GPG mode): plain text on
unlocked machines, ciphertext everywhere else.

- **Unlocking** happens inside the worktree: `cd .ai && git-crypt unlock`.
  Re-adding the worktree means unlocking again.
- **If transcript files look like binary,** the worktree is locked. Tell
  the user; don't try to work around it.
- **Losing the key loses the encrypted transcripts.** git-crypt's GPG mode
  keeps a copy of the key in the branch for each GPG key added
  (`git-crypt add-gpg-user`), so add at least two, one of them kept
  offline, and suggest the user store an exported key
  (`git-crypt export-key`) in their password manager.

## Writing notes

Belongs: status, plans agreed with the user, decisions and why while they're
still being worked out, lessons learned the hard way, measurements and how
to reproduce them, open issues with enough detail to pick up later, the
projects this one corresponds with. Doesn't: what the code or git history
already say, settled knowledge that belongs in the project's own docs, and
anything only the current conversation needs.

- Update the note that covers the topic instead of adding one. A new topic
  gets a new note and a row in the index, in the same change.
- Keep notes short. Date each (`*Updated YYYY-MM-DD*` under the title) and
  use absolute dates inside, never "today". Cite code commits by hash so
  claims can be checked.
- Say who decided: "the user chose X (2026-10-07)". A later agent needs to
  know a question is settled, and by whom, so it doesn't reopen it.
- Mark each item's state plainly (**Open**, **Fixed in `abc1234`**,
  **Fixed, not yet committed**) and update the marker when the state
  changes. A stale "pending" misleads more than no marker.
- When a decision settles, move it into the project's own docs (or tell the
  user it should go there) and leave a pointer in the note.
- Machine-specific facts (local paths, hardware, what's installed on one
  box) don't go here: the repo travels and the machine doesn't. Keep them in
  your own per-machine memory, and project facts here.
- Never commit credentials or keys. If the repository is public, the `ai`
  branch is too, so also write nothing private: no personal details,
  internal URLs, or other people's words verbatim.

## Processing the inbox

Messages from other agents land in `.ai/mail/inbox/`. A message there has
not been dealt with yet, so the inbox holds only unread mail. Read them in
the order they're listed (oldest first), and for each one:

1. Put what matters into the memory notes, in your own words, merged into
   the right topics rather than pasted in whole. A message that is
   reference material to consult again (a spec, a design, a patch) needn't
   be summarized: cite it from the notes by its path in `mail/received/`.
2. Move it, unchanged and under the same name, to `.ai/mail/received/`.
3. Commit the notes and the message together
   (`git -C .ai add memory/<note>.md mail/received/<file>`).

`received/` is never edited: it's the record of exactly what other projects
said, and with `sent/` it lists the whole correspondence in order. In a
public repo, a message with private details is summarized and then deleted
instead of filed, so the original is never committed.

A notice from a topic (a sender starting with `#`) isn't mail and is never
filed: read the post it points to if it bears on the work, take what
matters into the notes, and delete the notice. The topic keeps its own log.

## Intake and outtake

Two folders in the project's own directory, next to `.ai/`, are for
passing files between the user and the agents, and for nothing else:

- **`intake/`**: files the user shares with you. Read them when they bear
  on the task. They are the user's: don't move, edit or delete them unless
  asked.
- **`outtake/`**: files you share with the user: what they asked you to
  make, or what you made for them to take (a report, an export, a patch).
  Tell them it's there. Usually the lead puts files here. Leave them for
  the user to move or delete.

Each holds a `.gitignore` containing only `*`, so git ignores the folder and
everything in it. If one is missing when you need it, create it that way
(`mkdir -p outtake && printf '*\n' > outtake/.gitignore`).

## Committing

Commit on the `ai` branch, staging by path
(`git -C .ai add memory/release.md`), never with `git add -A` or `.`.
Other agents and the runtime write to the same branch, and an `-A` would
sweep their unfinished work into your commit. Follow the branch's own
message style (`git -C .ai log`).

Ask before pushing unless the user has said otherwise. Pull first
(`git -C .ai pull --rebase`): a runtime pushes transcripts at its shutdown,
and other machines push too. Push the branch by name
(`git -C .ai push origin ai`).

## Setting up .ai/ in a project

1. Ask the user for the project's handle (suggest the directory's name),
   and, if the repository is public, whether transcripts should also be
   encrypted (`transcript.encrypt`, see Transcripts).
2. In the code checkout, add `/.ai/` to `.gitignore` and commit it.
3. Create the branch and its worktree: `git worktree add --orphan -b ai .ai`
   (git 2.42 or later).
4. Create `.ai/.gitignore` from `assets/gitignore`, `.ai/config.yml` from
   `assets/config.yml`, and `.ai/memory/README.md` from
   `assets/memory-README.md`. The README restates these conventions, so
   agents without this skill can follow them too.
5. Create a `.gitkeep` in `.ai/mail/drafts/`, `mail/outbox/`, `mail/sent/`,
   `mail/inbox/` and `mail/received/`. (The `.gitignore` keeps the contents
   of drafts, outbox and inbox out of commits, but not their `.gitkeep`.)
   In the project's own directory, create `intake/` and `outtake/`, each
   with a `.gitignore` containing only `*`.
6. Seed memory with what you already know that belongs there (status,
   decisions in progress, a coordination note with the projects this one
   corresponds with), a
   note per topic, each indexed.
7. Commit on the branch, and push it (`git -C .ai push -u origin ai`) if
   the user agrees.

On another clone, `git worktree add .ai ai` checks the branch out.

## Moving an existing .ai/ onto its own branch

For a project whose `.ai/` is still committed with the code:

1. Make the branch from the notes' history:
   `git subtree split --prefix=.ai -b ai`. The branch holds `.ai/`'s
   contents at its root, with every commit that touched them.
2. In the code checkout: `git rm -r --cached .ai`, add `/.ai/` to
   `.gitignore`, and commit. The old notes stay in the code's history.
3. Move the old directory aside and check the branch out:
   `mv .ai .ai.old && git worktree add .ai ai`. Copy `arcana.token` (if
   any) across from `.ai.old/`, and move anything in its `intake/` to the
   project's `intake/` (Intake and outtake); they were never committed.
4. On the branch: add `.gitignore` from `assets/gitignore` and the `mail/`
   folders with their `.gitkeep`. Messages in the old `inbox/` haven't been
   read yet: take them out of git (`git -C .ai rm -r --cached inbox`), move
   them into `mail/inbox/`, and commit. Then process them as usual.
5. Push the branch if the user agrees, then remove `.ai.old/` once
   everything is across.

## The config

`references/config.md` documents `.ai/config.yml`: `handle`,
`description`, `mail.review`, `transcript.encrypt`, `transcript.redaction`
and `users`, and how a tool (in Crystal, say) reads the file.
Tools read it too, so add keys only by documenting them there first.
