# Project memory

Notes that AI agents working on this project keep for each other: status,
plans, decisions in progress and lessons that are not obvious from the code
or the git history. Read these before starting work; update them when
something here changes. `../config.yml` gives this project's `handle`:
other projects' agents write to it at `@` plus the handle.

`.ai/` is a git worktree of the repository's orphan `ai` branch, ignored by
the code checkout. Run git against it (`git -C .ai ...`), stage by path,
never `git add -A`, and push it by name (`git -C .ai push origin ai`). In a
public repository the branch is public too. Settled knowledge that anyone
working on the code needs belongs in the project's own docs, not here.

| File | What it holds |
|---|---|

Keep each note short and dated (`*Updated YYYY-MM-DD*`), with absolute
dates and commit hashes. Check the code or `git log` before acting on
anything here; notes go stale. Machine-specific facts don't belong here.
Never commit credentials or keys.

## Handling inbox notes

Messages from other projects' agents land in `.ai/mail/inbox/`. A note in
the inbox has not been dealt with yet, so the inbox holds only unprocessed
notes. To process one:

1. Commit the note as it arrived, before anything else, so the original is
   kept in history.
2. Put what matters into the memory notes here, in your own words.
3. Delete the note in a following commit, and cite the commit that still
   has it (`git -C .ai show <commit>:mail/inbox/<file>`).

If a note is reference material that will be consulted again, such as a
spec or a design, move it here as its own file instead of summarizing it.

## Outbound mail

The lead agent (the main session the user works with) writes mail on the
user's behalf, one file per message named by its address:
`<address>--<YYYY-MM-DD>-<topic>.md` (`@datadungeon--2026-10-10-schema.md`).

- Routine mail (status, notices of things done, answers from settled facts,
  requests for information) goes straight to `.ai/mail/outbox/`.
  Delivery puts it in the recipient project's `mail/inbox/` and moves it
  to `mail/sent/`, the committed record of what was said.
- Anything that commits the user or the project, makes a decision the user
  hasn't made, pushes back, shares something private, or that the user
  asked to see goes to `mail/drafts/` with a `Held: <why>` line, and waits
  for the user's approval. When unsure, hold. `mail.review: all` in
  `../config.yml` holds everything.
- Helpers (subagents, other sessions) never send: they put messages in
  `mail/drafts/` with a `By: <who>` line, and the lead reviews them like
  its own.
- Drafts and the outbox are machine-local and never committed. Never write
  into another project's `.ai/`, except to deliver into its `mail/inbox/`.

## Transcripts and records

`.ai/transcript/` holds session transcripts written by the agent runtime,
one tagged entry per event (`<E1043 …>…</E1043>`), always redacted before
they're committed, and encrypted with git-crypt if `transcript.encrypt` is
set. Each person numbers their own stream; a file's header names whose it
is. Read them, never edit them; find an entry with
`grep -rn '^<E1043 ' .ai/transcript`. Files that look like binary mean the
worktree is locked (`cd .ai && git-crypt unlock`).

`.ai/records/<handle>/` holds the records the runtime curates from them
(notes, summaries, memories), one file per version, never edited.

## Intake

The user shares files for the work at hand in `.ai/intake/`. Look there
when starting a session. The files are the user's: don't commit, move or
delete them unless asked. `.ai/.gitignore` keeps them out of commits.

## Arcana

Where the project uses the Arcana bus, messages sent over it are mail like
any other: they go through the outbox or drafts as above. Reading and
receiving bus mail is fine.
