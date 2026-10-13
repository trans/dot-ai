# Identity

Transcripts and records say who wrote them and on which machine, so that an
agent reading them later, maybe on another machine or for another person,
can tell what holds for it. A memory that the shell is fish is true on one
machine; a preference is one person's.

## The person

A person is who git says they are in the project: `user.name` and
`user.email` as git resolves them for the code checkout (its own config,
then the user's, then the system's). The email is the key, as on GitHub.

### Handles

Each person has a **handle**: short, lowercase, letters, digits and `-`.
Ids carry it (below), and transcript headers name it.

- **Registered:** the entry under `users:` in `.ai/config.yml` whose
  `emails` include the person's git email, compared without case. Several
  emails cover several machines.
- **Unregistered:** the local part of their email, lowercased, with any
  character outside letters, digits and `-` replaced by `-`. If that is
  already someone's registered handle or alias, the first label of the
  email's domain is appended (`pat` becomes `pat-acme`). With no email, the
  login name. A tool should suggest registering.
- **Taken:** a handle registered to someone else's emails is theirs. A tool
  must not register it for anyone else.
- **Renaming:** registering a different handle later lists the old one under
  `aliases:`. Ids committed under an old handle are never rewritten, so a
  reader treats a person's aliases as theirs.

```yaml
users:
  trans:
    name: Thomas Sawyer
    emails: [transfire@gmail.com, thomas@work.example]
    aliases: [thomas]
```

## The machine

A machine's name is git config's `ai.machine` if set (per user with
`--global`, or per clone), else the host name, with any character outside
letters, digits and `-` replaced by `-`. Transcript file names and headers
carry it, and so does every record.

Transcript headers also record the operating system and shell, the facts an
agent would otherwise assume about where earlier work happened.

## The project

A project's **handle** is `handle` in its `.ai/config.yml` (`ipck`).
Without one, it is the project directory's name, lowercased, each run of
characters outside letters, digits and `-` replaced by one `-`, trimmed of
`-` at either end, and prefixed with `agent-` if it doesn't then start with
a letter (`siliconcircus.lol` gives `siliconcircus-lol`). The project's
**address** is `@` plus its handle (`@ipck`): where other projects' agents
send mail (see [Mail](mail.md)).

Project handles and people's handles are separate: an address names a
project, and the `@` in an id names a person (`N17@trans`).

## Ids

Each person numbers their own transcript entries and their own records, so
two people never collide.

| Id | Is | Example |
|---|---|---|
| `E<n>@<handle>` | an entry in that person's transcripts | `E1043@trans` |
| `<code><n>@<handle>` | a record of the kind with that code, numbered in its author's own sequence for the kind | `N17@trans`, `CI4@pat` |

- **Codes** are one or two uppercase letters, each declared by the tool that
  owns the kind (Copious: `E` event, `M` memory, `CI` citation, `N` note,
  `S` summary, `F` file). `E` is always transcript entries.
- **Numbers** start at 1 and increase. They may have gaps; readers must not
  assume they don't.
- **Stored** ids always carry the handle: in record files, links, citations,
  and indexes.
- **Shown** without the handle to its owner (`N17`), with it to everyone
  else (`N17@trans`).
- **Read:** an id without a handle means the reader's own (theirs now, or
  under an alias).
- Free text an agent writes (a reply, a note's prose) is kept as written:
  inside one person's transcript, a bare `E12` is theirs.
