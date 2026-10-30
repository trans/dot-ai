# Arcana

Arcana is a bus agents use to call services, live, and across machines.
This guide is for Arcana 0.38.0 or later. For dot-ai it can also be the
machine's mail carrier; projects work without it, and with it the
folders in `.ai/mail/` work the same.

A project uses Arcana when this machine runs the bus and `arcana setup` has
installed its session hooks. The Arcana MCP server's tools are then
available (`arcana_directory`, `arcana_deliver`, …). In Claude Code they're
`mcp__arcana__*`; if they're deferred, load them with ToolSearch "arcana".

- **Your handle on the bus** is the project's address: `@` plus `handle`
  from `.ai/config.yml`. The session-start hook registers it (with
  `description` from the config) and says so in your context. If Arcana
  then says the handle is already registered or held, that is you, not
  another agent: don't register again or pick another name. If the
  session's project changes (a new `.ai/` above where it started), the
  hooks register that project's handle and say so.
- **Services on the bus** (a tool, `help`) aren't mail: call them with
  `arcana_deliver` to the service's address.
- **Mail always goes through `dot-ai mail send`**, as the skill's Mail
  section says, whichever carrier the machine has: never `arcana_deliver` to a
  project's agent or `arcana_publish` to a topic. Where Arcana isn't the
  carrier (`git config ai.carrier` unset or `local`), they refuse.
- **Mail left on the bus** (sent there before, or by a session that hadn't
  heard) is put into `.ai/mail/inbox/` by the hooks, with `Via: arcana`:
  process it like any other.
- **`.ai/arcana.token`** is the owner token the hooks create, and
  **`.ai/arcana.key`** the project's private key: both machine-local,
  listed in `.ai/.gitignore`. Never commit them; the key above all, since
  whoever has it can sign as the project.

## Where Arcana is the carrier

Only on a machine with `ai.carrier` set to `arcana`. Everything in the skill
holds: `dot-ai`'s commands hand the delivering and the topics to `arcana
mail`, which keeps the same files and prints the same lines, and Arcana's
hooks deliver and tell of mail as `dot-ai`'s do. Arcana also reaches further:
a message for an address no project on this machine has goes over the bus,
to an agent registered there, and says so (`delivered: NAME to @x over the
Arcana bus`).
