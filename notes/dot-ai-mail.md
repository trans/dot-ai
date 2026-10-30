# dot-ai's mail commands (once dot-ai-mail)

*Draft, 2026-10-14; updated 2026-10-30. Built 2026-10-15: `skills/dot-ai/scripts/dot-ai-mail`
0.1.0; 0.2.0 (2026-10-17) adds `Re:` and `Id:`; 0.3.0 (2026-10-27) adds
topics, `ai.carrier` and receipts; 0.3.1 (2026-10-29) leaves a message it
can't write from a sandbox for the hooks, saying so. 0.5.0 (2026-10-30,
plugin 0.5.0) renames it `dot-ai`, with the mail commands under `dot-ai
mail`, and adds `send`, `draft`, `done` and `rm`, so agents never name or
move mail files themselves (the user: one interface whatever the
carrier); `dot-ai-mail` stays as a shim for `dot-ai mail`. Tested by
`tests/dot-ai.sh` (`just test`); its hooks ship in the dot-ai plugin
(`hooks/hooks.json`).*

The local carrier of [Mail](../spec/mail.md): it delivers each project's
outbox on this machine, keeps the topics, and tells agents when mail or
posts are waiting and when their mail has been read, so the lead no longer
delivers by hand. It needs no
server and nothing beyond the file system, and it doesn't need Arcana.

## Form

- **One POSIX `sh` script**, `skills/dot-ai/scripts/dot-ai`, shipped
  inside the skill, and its hooks in the dot-ai plugin: installing the
  plugin installs both, in Claude Code and Codex alike. The hooks run it
  by its path in the plugin (`${CLAUDE_PLUGIN_ROOT}`, which Codex sets
  too), and the skill tells agents that path. Nothing to compile; it's written for Linux and macOS (tested under bash's and
  zsh's sh modes; dash isn't on the machine it was built on).
- **Needs** `find`, `sed`, `awk`, `date`, `mv`, `git` (for `ai.path`),
  and one of `sha256sum`, `shasum -a 256` or `openssl dgst -sha256`.
- **Reads one line of each config:** the top-level `handle:`, written
  plain (`handle: oyl`) or quoted with or without the `@`
  (`handle: "@oyl"`). A config whose handle it can't read that way is
  reported, and that project gets no mail from it. Without a `handle`,
  the directory's name, folded as [Identity](../spec/identity.md) says.

## Commands

| Command | Does |
|---|---|
| `dot-ai mail send ADDRESS TOPIC [--re ID] [DIR]` | Writes the message on standard input to the outbox, named from the time, the address and TOPIC folded to lowercase words joined by `-`, with `Re:` from `--re`; then delivers the outbox. Refuses a bad address, a `--re` that names nothing, or an empty message, writing nothing. |
| `dot-ai mail draft ADDRESS TOPIC [--re ID] [--why WHY] [--by WHO] [DIR]` | The same, kept in `drafts/`: `--why` is its `Held:` line, `--by` its `By:` line. The draft is an ordinary file there, which the agent may edit before it goes. (The user preferred "draft, then send" to `send --hold` and `release`, 2026-10-30.) |
| `dot-ai mail send NAME` | Sends a draft (its name, or path): moves it to the outbox without its `Held:` line (a `By:` line stays: it's the record) and delivers. |
| `dot-ai mail done NAME...` | Files inbox messages under `received/`. NAME is the file's name, its path, or the message's id. A topic's notice is removed instead; one filed already is removed. |
| `dot-ai mail rm NAME...` | Removes inbox messages without filing them (the sender's receipt says so), or drafts. For a message whose details can't be committed, after summarizing it. |
| `dot-ai mail deliver [DIR]` | Delivers everything in the outbox of the project at or above `DIR` (default: here). One line per message: delivered, or left in the outbox and why. |
| `dot-ai mail check [DIR]` | Lists the inbox, oldest first. Exits 1 when it's empty, for scripts. |
| `dot-ai mail topic [TOPIC DESCRIPTION]` | Makes a topic with a one-line description, or, alone, lists the topics with their number of posts and descriptions. A topic is given as `'#name'` (quoted, or the shell takes it for a comment) or `name`. |
| `dot-ai mail read TOPIC [--after N] [DIR]` | Prints the posts after the project's place in the topic (after post `N` with `--after`), oldest first, each under a `==> <file> <==` line, and moves the place on to the last one shown. |
| `dot-ai mail find [ADDRESS]` | Where an address's project is, or every project found with its address: to see why something wasn't delivered. |
| `dot-ai hook EVENT [--agent claude\|codex]` | What the session hooks run (below): `session-start`, `stop`, `prompt`, `session-end`. The plugin's hooks name no agent: `PLUGIN_ROOT` set means Codex (Claude Code sets only `CLAUDE_*`), else `CLAUDE_PROJECT_DIR` set means Claude Code, else Codex. |
| `dot-ai hooks` | Prints the hook entries to add to Claude Code's and Codex's settings, for use without the plugin. It doesn't edit them: JSON is the one thing `sh` can't safely rewrite. |

## Hooks

- **`session-start`:** deliver, then add to the agent's context everything
  in `.ai/mail/inbox/` (oldest first, by name), any message left in the
  outbox with the reason, what it delivered, how many posts each topic
  in `mail.follow` has after the project's place, and the receipts
  (below).
- **`stop`** (every time the agent would finish a turn): deliver, then, if
  there's anything this session hasn't been told of (new inbox files, a
  message newly left in the outbox, messages it just delivered, which the
  agent should commit, a followed topic's newest post), keep the agent
  going once to deal with it
  (Claude: exit 2 with the text on stderr; Codex: `decision: block`). What
  a session was told of is kept in
  `$XDG_RUNTIME_DIR/dot-ai/<session id>` (or under `$TMPDIR`), so a
  message the agent leaves for later never loops it, and
  `stop_hook_active` isn't needed. Files older than a week are removed.
  The receipts are told too, but only when there's something else to
  tell.
- **`prompt`** (`UserPromptSubmit`, as the user's prompt goes to the
  agent): only the receipts, added to the agent's context. It doesn't
  deliver, so it stays quick on every prompt. Codex has the same hook,
  with the same output.
- **`session-end`:** deliver, quietly.
- A hook never stops a session: anything that goes wrong is one line of
  output and exit 0 (2 only to keep the agent going). It reads
  `session_id` and `cwd` from the hook's JSON with `sed` (flat fields; no
  `jq`), and the project from `CLAUDE_PROJECT_DIR`, else `cwd`.

## Delivering

The spec's four steps, with these details:

- **Finding projects** exactly as the spec says: `ai.path`, else the
  outermost enclosing project, else the parent directory; `find` to 4
  levels, pruning hidden directories and `node_modules`, without `-L`.
- **Outbox names:** the address runs from after the time to the first
  `--`. One that starts with `#` is a post (Topics, below).
- **The message** for the id is everything after the header lines and the
  blank line, byte for byte, as the spec now says (Outbound files).
- **`Re:`** goes to the inbox file as it is, if it names a message's id
  (8 or more hex digits, so an older Arcana id fits too) or a topic's
  post (`#topic:number`); one that names neither stays in the outbox,
  with a reason. Like the other header lines, it isn't part of the id.
- **Filing** writes the original, with `Sent: <time> via local` and
  `Id: <id>` added to its header lines, to `sent/.<name>`, renames it into place, then removes
  the outbox copy. A run that stops between steps finds the message again
  next time, sees its id in the recipient's inbox or `received/`, and only
  files it.
- **A lock per outbox** (`outbox/.delivering`, a directory, so making it
  is atomic). The design had none, but the inbox name carries the time of
  delivery, so two runs a second apart would deliver the same message
  under two names. A run that finds the lock says `busy` and leaves the
  outbox; a lock older than two minutes is a crashed run's, and is cleared.
  Since 2026-10-29 the spec has it (The carrier's files), with `.posting`,
  `.receipts` and `mail/following`, so every carrier on a machine uses the
  same files and locks: Arcana, carrying the outbox, waits on dot-ai-mail
  and the other way round.
- **Never commits** (the spec leaves that to the agents).

## Topics

As the spec's Topics section says, in the topic home's `.ai/topics/`
(the first `ai.path` directory, else the outermost project at or above the
sender's):

- **Posting:** an outbox file to `#name` is checked like an address
  (names made like handles, joined by `.`), and stays in the outbox if the
  topic's folder doesn't exist. Its id, `Re:` check and message are a
  message's. Under the topic's lock (`.posting`, made and cleared like the
  outbox's), a post already ending in `-<id>.md` keeps its number (a run
  that stopped before filing); otherwise it takes the highest number there
  plus one, written to a hidden name and renamed into place. The original
  is filed under `sent/` with `Post:` after `Id:`, and the line printed is
  `posted: <name> to #name as post N`.
- **The lock** replaced the spec draft's first idea, taking a number by
  creating the file under it: two posts with one number have different
  names, so creating one never fails. The spec now says the lock.
- **Places** are `mail/following`, `<topic> <number>` lines, rewritten
  whole through a hidden file. `read` moves a place only forward, also
  with `--after`.
- **`mail.follow`** is read with `awk`, from the top-level `mail:` block:
  a flow list on the `follow:` line or a block list of `- ` items below
  it, each quoted or not. The hooks tell of an entry that isn't a topic,
  or a topic that doesn't exist, once per session.

## Receipts

Asked for by @mj for the user (2026-10-27, after three messages sat on
the bus for an agent that had gone offline): a way to know whether a
message was read, without looking in the other project's folders. A
command (`dot-ai-mail sent`, listing where each message is now) was the
first idea; the user preferred being told, without running anything.

- **Waiting:** each message `deliver` hands to a project (not a post)
  gets a line in the outbox's `.receipts`: id, address, the recipient's
  project and the outbox name, tab-separated. The project is kept so
  checking needs no search of `ai.path`. The outbox's ignore rule
  (`mail/outbox/*`) already keeps the file out of commits, which matters:
  it holds local paths. A line whose project doesn't start with `/` is
  another carrier's, for a recipient on another machine, and is left for
  it.
- **Checking:** a file ending in `-<id>.md` in the recipient's
  `received/` means read; one in its inbox means still waiting; neither
  means it left the inbox unfiled; no `.ai/mail/` at the project means it
  moved. Each but the waiting is told once (`@oyl read <name>`) and its
  line dropped; the file goes when the last one is.
- **Never a turn of their own:** the Stop hook can only add text by keeping
  the agent going, so receipts wait for the `prompt` hook, a session
  start, or a Stop that has something else to say.
- **The outbox's lock** guards the rewrite against a delivery appending at
  the same time; the `prompt` hook doesn't wait for it, and leaves the
  receipts for next time.

## The carrier

Since the spec's carrier model (the user, 2026-10-25), one program on a
machine carries mail: git config's `ai.carrier`, `local` (`dot-ai`)
when unset. Under `arcana`, `deliver`, `topic` and `read` are handed to
`arcana mail` with their arguments (since 0.5.0; before, they refused),
and `send` writes the file and hands over the delivery; under
a carrier `dot-ai` doesn't know, they refuse. The hooks stay quiet under
any other carrier; `check`, `find`, `done` and `rm` work under all. Arcana, on a `local` machine, stays out of mail in
turn: from arcana 0.38 its hooks don't tell of mail, it writes no mail
files, and `arcana_deliver` to a project or `arcana_publish` refuses,
pointing to the outbox. Mail already on the bus is still written to the
inbox as `arcana_receive` takes it.

This replaces the layers of 2026-10-14 (both carrying mail, each
announcing its own place, and the lead sending over the bus what
dot-ai-mail left in the outbox). Mail between machines is the one thing
the local carrier can't do; [git-carrier.md](git-carrier.md) sketches it
over a shared git repository.

## Decided: dot-ai-mail never calls Arcana

**Superseded in part, 2026-10-30.** The user asked for one mail interface
whatever the backend, so `dot-ai mail` is that interface, and where
`ai.carrier` is `arcana` it hands the carrier's work to `arcana mail`.
Otherwise it still never calls Arcana and never needs it, and it doesn't
step aside just because Arcana is installed: only the user's `ai.carrier`
moves the carrier's work. What follows is the decision as it stood.

The user decided (2026-10-16, through @arcana: `…-e844c843.md` in ipck's
`.ai/`): dot-ai-mail is light mail for one machine without Arcana, so it
doesn't call Arcana even when Arcana is installed. Each tool announces its
own place, as above, rather than dot-ai-mail being the one voice.
@arcana's earlier proposal for one voice (2026-10-14, `…-51da5b86.md`: an
`arcana hook drain` that dot-ai-mail's Stop hook runs first) was built,
then removed before release. dot-ai stands on its own and
leads on to Arcana, which adds what files can't reach (other machines,
cloud agents, live sessions, services) without changing anything in
`.ai/`. Nor does dot-ai-mail step aside when Arcana is installed: Arcana
would have to re-implement local delivery, and nothing would be delivered
while the bus is down.

## Decided: mail keeps its record

Mail is filed under `sent/` and `received/` even where transcripts are
committed: the user agreed (2026-10-17), after asking whether transcripts
could be the record. Claude Code and Codex commit no transcripts, so for
most projects the mail folders are the only committed copy; each file is
one message, word for word, named by time, peer and topic; and it records
what two projects said to each other, on both sides. Where a runtime
commits transcripts there's no second copy: a Copious agent pins a mail
file with `view`, pinned views aren't persisted, and the transcript keeps
only the call. Since `received/` is never edited, the path is a lasting
reference.

## Decided: a session's project is the nearest `.ai/` above it

@arcana's review (2026-10-16, `…-6d54cbb1.md`) found that dot-ai-mail
walks up to the nearest `.ai/` while Arcana's hooks take a directory
without one as a project of its own, and suggested stopping the walk at
the top of the git repository. The user decided (2026-10-17) that the
walk is right, as [Layout](../spec/layout.md) already said: a directory
without its own `.ai/` belongs to the project above it, whose agent is
responsible for it until the user gives it one. Arcana's hooks and bridge
now walk up the same way (the user, 2026-10-17; arcana 0.35.5, `1cb0528`,
`…-8f32ce65.md`), so both tools find the same project.

## Decided: `arcana_deliver` files the `sent/` copy

The mirror of `arcana_receive` writing the inbox file: an agent can send
over the bus without the outbox, and then nothing reached `sent/`. The
user decided (2026-10-17, `…-19d7c47a.md` in ipck's `.ai/`) that
`arcana_deliver` writes the copy itself (arcana 0.35.5, `0521bc2`, not
released yet), for a message from the project's address to an agent.

## Fixed: a message dot-ai-mail can't place was filed twice

When dot-ai-mail leaves a message in the outbox (its recipient isn't on
this machine), the lead sends it over the bus. Arcana 0.36.0 files its own
copy, and the skill then had the lead move the outbox file to `sent/` as
well, so the message was filed twice under two names. Since 2026-10-19
(plugin 0.3.1) the lead deletes the outbox file once `arcana_deliver`
returns `sent_file`. Arcana's copy is named by the time it was sent, not
the time it was written, and a helper's `By:` line isn't kept. If that
matters, Arcana could send the outbox file itself (`arcana send FILE`, or
a `file` argument), keeping its name and header lines; @arcana offered it.

## Copious

A copious session is the "tool that runs agents" the spec mentions: its
dotai plugin can call `dot-ai-mail deliver` at session start and end, or
do the same steps itself in Crystal. Either way the ids must match, which
is why the spec should pin down the header lines.

## Not built yet

- Mail between machines without a bus (an open question in the README;
  [git-carrier.md](git-carrier.md)).
- Windows.
- A command to change carriers, moving a topic's posts with their
  numbers (the spec's Changing carriers).
