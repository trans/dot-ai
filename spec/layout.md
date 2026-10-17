# Layout

## Where `.ai/` lives

`.ai/` is the repository's **`ai` branch**: an orphan branch, sharing no
history with the code, checked out into `.ai/` as a git worktree. The code
checkout ignores it (its `.gitignore` lists `/.ai/`), so notes and
transcripts stay out of the code's history and its CI, and one clone carries
both.

```sh
git worktree add --orphan -b ai .ai      # create it (git 2.42 or later)
git worktree add .ai ai                  # check it out in another clone
```

A project may keep `.ai/` in a **separate repository** instead, cloned into
`.ai/` and ignored the same way: for example, a public project whose
transcripts must stay private without encryption. Everything in this spec
applies to either arrangement. `git -C .ai remote -v` tells them apart.

A tool must treat `.ai/` as present only when it is a worktree or repository
of its own: `git -C .ai rev-parse --show-toplevel` names `.ai/` itself. A
plain `.ai/` directory inside the code checkout (an older arrangement, its
notes committed with the code) gets no transcripts or records; notes and
mail work in it all the same.

The branch is as visible as the repository. On a public repository anyone
can read it, which is why everything committed is protected first (see
[Protection](protection.md)).

## Projects inside projects

A project may sit inside another: a meta-project whose agent oversees the
projects below it (`c0/` holding `c0/c0-cr/`, each with its own `.ai/`).
Each is a project of its own, with its own `.ai/`, handle and mail. Only
real nesting counts: a symbolic link to a project elsewhere doesn't make it
part of the directory holding the link. The project an agent works in is
the nearest directory, at or above where it works, that holds `.ai/`. So a
directory without its own `.ai/` belongs to the project above it, whose
agent is responsible for it until the user gives it an `.ai/` of its own;
from then on that agent only oversees it.

An overseer may read the `.ai/` of the projects below it (their status,
their notes). It writes to them only by mail.

## The directories

```
.ai/
  .gitignore     keeps the machine-local files below out of commits
  config.yml     settings for agents and tools (Config)
  arcana.token   Arcana's owner token, if the project uses it    machine-local
  memory/        notes agents keep (Memory)
    README.md    the index
  mail/          messages between agents (Mail)
    drafts/      waiting for review                              machine-local
    outbox/      cleared to go                                   machine-local
    sent/        what was sent
    inbox/       what arrived, not yet read                      machine-local
    received/    what arrived and was read
  transcript/    session transcripts, protected (Transcripts)
  records/       curated records, one file per version (Records)
```

Everything not marked machine-local is committed. Each `mail/` folder holds
a `.gitkeep`, so it exists in a fresh checkout.

The branch's `.gitignore`:

```gitignore
arcana.token
mail/drafts/*
!mail/drafts/.gitkeep
mail/outbox/*
!mail/outbox/.gitkeep
mail/inbox/*
!mail/inbox/.gitkeep
```

## The user's folders: `intake/` and `outtake/`

Files passed between the user and the agents sit in the project's own
directory, next to `.ai/`, where the user can get at them:

```
intake/      files the user shares with the agents
outtake/     files an agent (usually the lead) shares with the user
```

That's all they are for. `intake/` is the user's: agents read what's there
and don't move, edit or delete it unless asked. An agent puts in `outtake/`
what it makes for the user to take (a report, an export, a patch), and
leaves it for the user to move or delete.

Neither is ever committed. Each holds a `.gitignore` containing only `*`,
which keeps the folder and everything in it out of the code repository
without an entry in the project's own `.gitignore`. Setting up `.ai/`
creates both, and an agent that finds one missing when it needs it creates
it the same way.

## This machine's side: `.var/ai/`

What must not leave the machine, or hasn't been protected yet, lives in the
code checkout under `.var/ai/`, which the code repository ignores:

```
.var/ai/
  config.yml     this machine's settings, over the project's (Config)
  transcript/    transcripts as written, before protection (Transcripts)
```

In a project without `.ai/`, `.var/ai/transcript/` is the only copy of its
transcripts and must be kept. In a project with `.ai/`, it is a buffer: a
file there may be deleted once every entry in it is committed to
`.ai/transcript/` and the run that wrote it is over, except a file with
withheld entries (see [Protection](protection.md)), which is the only copy
of them.

## Who writes what

| Path | Written by | Edited after? |
|---|---|---|
| `config.yml` | people, by hand | yes; no tool rewrites it, so its comments survive |
| `memory/` | agents | yes, the notes are kept current |
| `mail/` | agents, delivery processes | `sent/` and `received/` never; the rest move between folders |
| `transcript/` | runtimes | never; files only grow |
| `records/` | runtimes | never; each change is a new file |

## Committing

- **Stage by path, never with `git add -A` or `.`.** Several agents, the
  runtime and the user share the branch, and a sweep would commit someone
  else's unfinished work.
- **Commit only what is yours to commit:** a runtime its transcript and
  record files, an agent the notes and mail it wrote. A runtime should use
  `git commit --only <paths>`, so what others have staged stays staged.
- **Pull before pushing** (`git pull --rebase`), and only when no tracked
  file is modified: no autostash. A rebase that fails is aborted and the
  push left for later. Never force-push the branch.
- **Push the branch by name** (`git push origin ai`). Agents ask the user
  before pushing unless told otherwise. A runtime pushes when its session
  ends.
- A runtime must run git non-interactively (no credential prompts, SSH in
  batch mode) and with a time limit, and a failed commit, pull or push must
  never stop the session.
- Commit messages follow the branch's own style (`git -C .ai log`). The
  branch has no CI, but messages may end with `[skip ci]` where a host would
  otherwise run some.
