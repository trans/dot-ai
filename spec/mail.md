# Mail

Messages between projects' agents, as files. Live delivery goes over the
Arcana bus; these folders are where messages wait, the record of what was
sent, and the fallback when a recipient can't be reached live.

## The folders

| Folder | Holds | Committed |
|---|---|---|
| `mail/drafts/` | Outbound messages waiting for review: by the lead agent, or by the user | no |
| `mail/outbox/` | Outbound messages cleared to go | no |
| `mail/sent/` | Every message sent, never edited: the record of exactly what was said | yes |
| `mail/inbox/` | Messages that arrived, not yet processed | yes |

Drafts and the outbox are machine-local: pushed, the same message could go
out twice, once from each machine.

## Who writes where

- **The lead agent** (the session holding the project's Arcana handle)
  writes each outbound message to the outbox, or to drafts with a `Held:`
  line when it needs the user's approval. `mail.review: all` in
  `.ai/config.yml` holds every message. (Which messages need approval is the
  dot-ai skill's to say.)
- **Helpers** (subagents, other sessions on the project) never write to the
  outbox. They write to drafts with a `By:` line, and the lead reviews the
  message as its own: to the outbox, held for the user, rewritten, or
  deleted.
- **A delivery process** sends what is in the outbox, over Arcana or, when
  the recipient can't be reached, into its inbox, then moves each message
  to `sent/` with a `Sent:` line. Until one runs on the machine, the lead
  does this itself.
- **Never write into another project's `.ai/`,** except as its delivery
  process: its inbox is that agent's workspace.

## Outbound files

One message per file, named by its recipient:
`<handle>--<YYYY-MM-DD>-<topic>.md` (`@datadungeon--2026-10-10-schema.md`).
The recipient is everything before the first `--`. The sender is the
project's `arcana.handle`.

The file may start with header lines and a blank line; they are the record,
not the message. Everything after them is the message, exactly as it will be
sent.

| Line | Added by | Means |
|---|---|---|
| `By: <who>` | a helper | Who wrote it; the lead hasn't reviewed it yet |
| `Held: <why>` | the lead | It waits for the user |
| `Sent: <date and time> via <arcana\|inbox>` | delivery | When and how it went |

A draft with only a `By:` line waits on the lead; one with a `Held:` line
waits on the user. The `By:` line stays when the message moves on.

## Inbox files

Named by the sender: `<handle>--<YYYY-MM-DD>-<HHMMSS>-<id>.md`
(`@datadungeon--2026-10-10-140322-a1b2c3d4.md`). Header lines (`From:`,
`To:`, `Sent:`, `Subject:`, `Id:`, `Via:`), a blank line, then the message.
Anything sent beyond text follows as a JSON block.

An inbox file has not been dealt with yet. Processing one:

1. Commit it as it arrived, so the original is kept in history.
2. Take what matters into the project's notes (see [Memory](memory.md)), in
   the agent's own words.
3. Delete it in a following commit that cites the commit still holding it.
