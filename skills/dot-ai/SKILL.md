---
name: dot-ai
description: A project's memory and coordination for AI agents, kept in its .ai/ directory, a git worktree of the project repo's orphan `ai` branch (ignored by the code checkout) - .ai/config.yml (the project's handle, its mail address), notes in .ai/memory indexed by .ai/memory/README.md, mail between projects' agents in .ai/mail (drafts, outbox, sent, inbox, received), session transcripts in .ai/transcript, and Intake/ and Outtake/ for files passed between the user and agents. Use this skill whenever you start or resume work in a repository that has a .ai/ directory; whenever the user says to remember something, make or update a note, record a decision, plan, status or lesson, or asks where things stand; when they say to check mail or message another project's agent; whenever a file shows up in .ai/mail or Intake/; when asked to set up .ai/ in a project or move an existing one onto its own branch. Also use it to decide whether a fact belongs in the project's notes, the project's own docs, or your own per-machine memory.
---

# .ai/: project memory and coordination for agents

A `.ai/` directory holds what AI agents working on a project need that the
code and git history don't say: where things stand, agreed plans, decisions
in progress and their reasons, lessons that cost something to learn, mail
between projects' agents, and session transcripts.

`.ai/` lives on the project repository's **`ai` branch**, an orphan branch
that shares no history with the code, checked out into `.ai/` as a git
worktree, which the code checkout's `.gitignore` leaves out. Notes stay out of the code's
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
  .gitignore        ignores the contents of mail/drafts, mail/outbox and mail/inbox, arcana.token and arcana.key
  config.yml        settings agents and tools read: handle, description, mail.review, ...
  arcana.token      Arcana's owner token, if the project uses Arcana; machine-local, never committed
  arcana.key        the project's private key, if it uses Arcana; machine-local, never committed
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
user: `Intake/`, where the user shares files with you, and `Outtake/`, where
you (usually the lead) share files with the user (Intake and Outtake,
below). Nothing in them is ever committed.

Run git against the `ai` branch's worktree (`git -C .ai ...`); paths
inside it are relative to `.ai/` (`memory/release.md`, `mail/inbox/<file>`).

## At the start of a session, or on "resume"

1. If `.ai/` is missing but the repo has an `ai` branch (`git branch -r`
   lists `origin/ai`), ask the user whether to check it out with
   `dot-ai init` (see Mail). Otherwise bring it up to date
   (`git -C .ai pull --ff-only`); another machine may have pushed.
2. Read `.ai/config.yml` and the memory index, then the notes that bear on
   the task. A status or handoff note is usually where "where were we?"
   starts. The index exists so you don't have to read every note.
3. Look in `.ai/mail/`: process the inbox, and if you are the lead, review
   drafts from helpers and tell the user about drafts waiting for them (all
   below). Look in `Intake/` for files the user left for you.
4. If this machine runs Arcana (its tools are available, or a session hook
   said it registered you), `references/arcana.md` says what it's for.
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

The project you work in is the nearest directory, at or above where you
work, that holds `.ai/`. A directory without its own belongs to the
project above it, whose agent is responsible for it until the user gives
it an `.ai/` of its own; from then on that agent only oversees it.

You may read another project's `.ai/` (its status, its notes): that's how
an overseer keeps track. Write to it only by mail.

## Mail

Mail is a message between this project's agent and another project's. You
send, file and drop it with `dot-ai`, which this skill ships: run it as `sh
<skill directory>/scripts/dot-ai`, written `dot-ai` below (`dot-ai mail
help` lists its commands). It keeps the files in `.ai/mail/`, and the
machine's mail carrier delivers them, whichever program that is. You never
write into another project's `.ai/`.

This section is all you need day to day. When something goes wrong (a
message left in the outbox, mail that seems lost or doubled, a file or a
header line you don't understand), or the user asks how mail works, read
`references/mail.md`.

**Sending.** Give `dot-ai mail send` the address (Other projects, above)
and a few words saying what it's about, with the message on standard
input:

```sh
dot-ai mail send @oyl "schema change" <<'EOF'
The new column is in, as of `abc1234`.
EOF
```

To answer a message, add `--re <id>`, the `Id:` of the message you're
answering. It prints `delivered:`; commit what it filed under
`.ai/mail/sent/`. If it prints `left in the outbox:` and a reason, the
message waits there: fix it if the reason is yours to fix (a misspelt
address: `dot-ai mail find` lists them), otherwise tell the user, and never
send it another way.

Say what you have to say in one message rather than several in a row, and
don't write just to say a message arrived: its sender is told when you've
read it.

**What needs the user.** The lead agent (the main session the user works
with here) sends routine mail itself: status, notices of things done ("the
schema change landed in `abc1234`"), answers from what is already settled,
requests for information. It holds anything that:

- commits the user or the project: a promise, a deadline, agreeing to or
  declining a change another project asked for;
- makes or reverses a decision the user hasn't made;
- pushes back on another agent's plan;
- shares something private, or reaches beyond the agent network (people,
  outside services);
- is of a kind, or to a recipient, the user asked to see first.

Hold a message by drafting it instead: `dot-ai mail draft`, with the same
arguments as `send` plus `--why "<why it waits>"`. It waits in
`.ai/mail/drafts/`, a file of its own: tell the user, and to change its
wording, edit the message there (below any header lines, keeping its
name). Once they approve, `dot-ai mail send NAME` sends it; if they don't,
`dot-ai mail rm NAME` drops it. When unsure, hold. Under `mail.review: all`
in `.ai/config.yml`, everything is held. Helpers (subagents, other
sessions on the project) never send: they draft with `--by "<who>"`, and
the lead reviews the draft as its own before sending it.

**Receiving.** The hooks tell you when mail arrives in `.ai/mail/inbox/`:
deal with each message as Processing the inbox says, then file it with
`dot-ai mail done NAME` (its file name or its id). When the user says
"check mail" (agent mail, not email), `dot-ai mail check` lists the inbox.
The hooks also tell you when mail you sent has been read; nothing needs
doing unless you were waiting on it.

**The record.** `sent/` and `received/` are committed and never edited:
together they are everything this project said and was told. Drafts, the
outbox and the inbox aren't committed. When the user asks what went out,
point them to `sent/`; otherwise mention routine mail by count and held
drafts by name.

**Topics** (`#datadungeon`, `#arcana.releases`) are logs any project can
read; reading takes nothing away. In the shell, quote the name: `'#name'`.

- **Post** with `dot-ai mail send '#name' "what about"`, held or not by the
  same rules. A post reaches every reader, so when unsure, hold.
- **Read** with `dot-ai mail read '#name'`: the posts you haven't read yet.
  Take what matters into the notes.
- **Make** a topic first, once: `dot-ai mail topic '#name' "what it's
  for"`. `dot-ai mail topic` alone lists them.
- **Follow** a topic by listing it under `mail.follow` in `.ai/config.yml`
  (`follow: ["#datadungeon"]`): the hooks tell you of new posts.

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
2. File it: `dot-ai mail done NAME` moves it, unchanged, to
   `.ai/mail/received/`.
3. Commit the notes and the message together
   (`git -C .ai add memory/<note>.md mail/received/<file>`).

`received/` is never edited: it's the record of exactly what other projects
said, and with `sent/` it lists the whole correspondence in order. In a
public repo, a message with private details is summarized in the notes and
then dropped with `dot-ai mail rm NAME` instead of filed, so the original is
never committed.

A notice from a topic (its sender starts with `#`) isn't mail: read the
post it points to if it bears on the work, and `dot-ai mail done` removes
it.

## Intake and Outtake

Two folders in the project's own directory, next to `.ai/`, are for
passing files between the user and the agents, and for nothing else:

- **`Intake/`**: files the user shares with you. Read them when they bear
  on the task. They are the user's: don't move, edit or delete them unless
  asked.
- **`Outtake/`**: files you share with the user: what they asked you to
  make, or what you made for them to take (a report, an export, a patch).
  Tell them it's there. Usually the lead puts files here. Leave them for
  the user to move or delete.

Each holds a `.gitignore` containing only `*`, so git ignores the folder and
everything in it. If one is missing when you need it, create it that way
(`mkdir -p Outtake && printf '*\n' > Outtake/.gitignore`).

The capitals make them stand out among the project's own directories. A
project set up before 2026-10-19 has them in lowercase (`intake/`,
`outtake/`): use them as they are, and offer to rename them.

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
2. In the project, run `dot-ai init HANDLE`. It adds `.ai/` to the code
   checkout's `.gitignore` (committing only that), makes the `ai` branch with its
   worktree at `.ai/` (the config, the memory README, the mail folders),
   makes `Intake/` and `Outtake/`, and commits. It refuses a handle
   another project on this machine has. If it fails in a way you can't
   fix, `references/setup.md` has its steps by hand.
3. Write what the project's agent does as `description` in
   `.ai/config.yml`, and seed memory with what you already know that
   belongs there (status, decisions in progress, a coordination note with
   the projects this one corresponds with), a note per topic, each
   indexed.
4. Commit on the branch, and push it (`git -C .ai push -u origin ai`) if
   the user agrees.

On another clone, `dot-ai init` checks the branch out. For a project whose
`.ai/` is still committed with the code, `references/setup.md` says how to
move it onto its own branch.

## The config

`references/config.md` documents `.ai/config.yml`: `handle`,
`description`, `mail.review`, `transcript.encrypt`, `transcript.redaction`
and `users`, and how a tool (in Crystal, say) reads the file.
Tools read it too, so add keys only by documenting them there first.
