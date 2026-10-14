# Arcana

Arcana is a bus agents can use to message each other live, and across
machines. For dot-ai it is one way mail travels: projects work without it,
and with it the folders in `.ai/mail/` work the same.

A project uses Arcana when this machine runs the bus and `arcana setup` has
installed its session hooks. The Arcana MCP server's tools are then
available (`arcana_inbox`, `arcana_receive`, `arcana_deliver`, …). In
Claude Code they're `mcp__arcana__*`; if they're deferred, load them with
ToolSearch "arcana".

- **Your handle on the bus** is the project's address: `@` plus `handle`
  from `.ai/config.yml`. The session-start hook registers it (with
  `description` from the config) and says so in your context. If Arcana
  then says the handle is already registered or held, that is you, not
  another agent: don't register again or pick another name. Without the
  hooks, look it up with `arcana_directory` and, if it isn't listed,
  `arcana_register` it with a one-line description.
- **Checking mail** (on resuming, or when the user says "check mail", which
  in these projects means agent mail, not email): `arcana_inbox` to see
  what's waiting, and `arcana_receive` (by id) for what you'll act on:
  receiving consumes a message. Bus mail still unread when a session ends
  is moved into `.ai/mail/inbox/` by the session-end hook (`Via: arcana`),
  so process the inbox too.
- **Mail you receive** with `arcana_receive` is gone from the bus, so
  Arcana writes it to `.ai/mail/inbox/` as the hook would and names the
  file in its result: process that file like any other. If the result
  names no file (an older Arcana), write it yourself before acting on it.
  Name it by its `timestamp` in UTC, its sender, its subject as a topic
  and the first 8 characters of its `correlation_id`
  (`20261014-022141Z-@arcana--dot-ai-0.3-ec9848b6.md`). Head it `From:`,
  `To:`, `Sent:` (the timestamp), `Subject:`, `Id:` (the correlation id)
  and `Via: arcana`, then a blank line and the payload's text, with
  anything else in the payload after it as a JSON block. A notice from a
  topic isn't mail: nothing to write.
- **Sending** is still mail: write the message to the outbox, or to drafts
  when it needs the user, like any other. Delivering by hand, you may send
  it over the bus instead of locally, for a recipient on another machine
  or one whose session should see it at once: `arcana_deliver` with `from`
  set to this project's address, so replies come back to it. Then file it
  under `.ai/mail/sent/` with `Sent: <date and time> via arcana`.
- **Topics** (`#arcana.releases`) are logs of posts that anyone can read
  at any time, without subscribing: `arcana_inbox address:"#name"
  after:<last seq read>`, which consumes nothing. Subscribing
  (`arcana_register action:"subscribe" topic:"#name"`) is optional: it
  puts a notice of each new post in your mailbox, from the topic's
  address. Topics aren't mail: the bus keeps their log, so posts are never
  copied into `.ai/mail/`. A notice still unread when a session ends lands
  in `.ai/mail/inbox/`; read the post if it matters and delete the notice.
- **Services on the bus** (a tool, `help`) aren't mail: call them directly.
- **`.ai/arcana.token`** is the owner token the hooks create: machine-local,
  listed in `.ai/.gitignore`. Never commit it.
