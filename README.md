# dot-ai

*Draft 0.3, 2026-10-13*. 0.3: mail files are named time first
(`20261013-190539Z-@arcana--topic.md`), so folders list in order; the inbox
is machine-local, and mail once read is filed under `mail/received/`;
`intake/` and `outtake/` move out of `.ai/` into the project's own
directory. 0.2: mail no longer depends on Arcana. Projects are found by
searching for `.ai/` directories and mail is delivered as files, Arcana
being one transport among others; the project's address comes from the
top-level `handle`, which replaces `arcana.handle`.

A project's `.ai/` directory holds what AI agents working on it need that the
code and its history don't say: where things stand, decisions in progress,
mail between agents, the transcripts of their sessions, and the curated
records taken from those transcripts. It lives on the repository's orphan
`ai` branch, so it travels with every clone and stays out of the code's
history.

This repository is the specification: the layout, the file formats, and the
rules that keep what is committed safe to publish. Any tool or agent that
reads or writes `.ai/` follows it.

| Document | Covers |
|---|---|
| [Layout](spec/layout.md) | Where `.ai/` lives, its directories, what is committed and what stays on the machine, how tools commit |
| [Config](spec/config.md) | `.ai/config.yml` and this machine's `.var/ai/config.yml` |
| [Identity](spec/identity.md) | People, machines, projects, and the ids that hold across them (`N17@trans`, `E1043@trans`) |
| [Transcripts](spec/transcript.md) | The transcript format: files, headers, entries, numbering, reading |
| [Records](spec/records.md) | Curated records as files: one per version, front matter, removal |
| [Protection](spec/protection.md) | What is masked and redacted before anything is committed, and encryption |
| [Mail](spec/mail.md) | Messages between projects' agents: addresses, folders, finding projects, delivery |
| [Memory](spec/memory.md) | The notes agents keep in `memory/` |

## Terms

"Must" and "must not" are requirements: a tool that breaks one can lose or
expose someone's work. "Should" is the expected behaviour, with room for a
reason not to. A **tool** is anything that writes `.ai/`: an agent runtime,
an agent following the dot-ai skill, a hook. A **runtime** is a tool that
runs agents and writes their transcripts.

## Related

- **The dot-ai skill** (`skill/`) tells an agent how to work with `.ai/`
  day to day (when to read notes, how to triage mail). This spec is what
  the skill's conventions rest on, and a change to one goes into the other
  in the same commit. `just install` copies it to Claude Code's and
  Codex's skills directories (copies, not links, so they don't depend on
  where this repository is checked out); `just diff` shows how the
  installed copies differ.
- **Copious** is the first runtime to implement the transcript, record and
  protection parts. Its own canon covers how it does so (numbering, the
  writer, curation, the index).

## Open questions

- **Duplicate E-numbers.** One user on two machines writing at once, without
  pulling in between, can number two entries the same. Readers resolve the
  duplicate to the newer file (see Transcripts); a way to name either one
  exactly (by machine, say) isn't settled.
- **Amending someone else's record.** Only a record's author writes its
  versions today. Whether another user can amend or retract it, and how, is
  open.
- **Encrypting records.** `transcript.encrypt` covers `transcript/` only.
  Whether records should be encrypted with it is open.
- **Lighter redaction under encryption.** Encrypted transcripts are redacted
  at the configured level all the same. Whether encryption could allow
  redacting less, or not at all, is open.
- **Signing and keys.** Runtimes commit with plain `git commit`, so commit
  signing applies once the user turns it on in git. Key fingerprints could
  tell apart machines with the same name, and age encryption to SSH keys
  could replace git-crypt.
- **A format version.** Transcript headers and record files don't yet say
  which version of this spec they follow.
- **Two checkouts of one project** on a machine (a second clone to try
  something in, say) both claim its address, so mail to it isn't
  delivered. A way to mark the one that receives isn't settled.
- **Mail across machines without a bus.** Local delivery reaches only this
  machine. Committing into the recipient repository's `ai` branch would
  reach any machine with git access to it, but the inbox isn't committed,
  so such mail would need a committed folder of its own.
- **Mail on a public branch.** `mail/sent/` and `mail/received/` are
  committed, so on a public repository they are public. Whether they need
  redaction or encryption is open.
