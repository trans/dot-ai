# .ai/config.yml

Settings read by AI agents (through the dot-ai skill) and by tools. YAML,
because Crystal's standard library reads it (it has no TOML). Every key is
optional, and readers ignore keys they don't know.

```yaml
arcana:
  handle: "@oyl"    # this project's agent on the Arcana bus
  description: >    # what that agent does, for other agents
    The agent for Oyl, a ...
mail:
  review: triage    # or "all": every outbound message waits for approval
transcript:
  encrypt: false    # true: also encrypt committed transcripts (git-crypt)
  redaction: standard
users:              # the people working here, by handle
  trans:
    name: Thomas Sawyer
    emails: [transfire@gmail.com]
    aliases: [thomas]   # handles they used before, if any
```

| Key | Type | Default | Meaning |
|---|---|---|---|
| `arcana.handle` | string | none | The Arcana address of an agent working in this project: `@` plus the project's name by convention (`@oyl`, `@datadungeon`). Agents register and receive mail under it, and send with it as `from`. The Arcana session hooks register it at session start (a handle without the `@` gets one); with none, they fall back to `@` plus the directory name, and an agent asks the user. |
| `arcana.description` | string | none | One or two sentences on what this project's agent does. The session hooks put it in the agent's Arcana directory listing, so other agents can tell what it is for. `>` folds a multi-line value into one paragraph. |
| `mail.review` | string | `triage` | Which outbound mail waits for the user's approval. `triage`: the lead agent decides per message, sending routine mail to the outbox and holding the rest in drafts. `all`: every message waits in drafts. |
| `transcript.encrypt` | boolean | `false` | Encrypt committed transcripts on the `ai` branch with git-crypt (GPG mode), on top of redaction. Losing every key loses them, so keep two GPG keys, one offline. |
| `users.<handle>` | map | none | A person working in this project, by handle (short, lowercase, letters, digits and `-`): `name`; `emails`, every address they commit with; and `aliases`, handles they used before this one (ids under them stay theirs). A person's handle is the entry whose `emails` include their git `user.email`; unregistered, it's their email's local part. Records and transcript entries carry it (`N17@trans`, `E1043@trans`), shown without it to its owner. Each contributor adds their own entry; a handle already registered to someone else's emails is taken. |
| `copious` | map | none | Settings for tools built on Copious (ipck), by path: `plugins`, `memory.curate`, `orchestrator.max_depth`, `permissions.allow`, and so on; copious's README ("Settings") lists them. Each machine can override them in its own `.var/ai/config.yml` (the same shape, never committed); `ipck config set` writes there. |
| `transcript.redaction` | string | `standard` | What the AI redaction pass removes before transcripts are committed. `standard`: credentials, contact details (emails, phone numbers, street addresses), internal hosts and URLs, and the contents of private files from outside the project; names stay. `strict`: also people's names, other people's quoted words, and remarks not meant for others. Secrets are masked at every level. |

The dot-ai spec (the user's `dot.ai` repository, `spec/config.md`) is the
normative version of this table; keep the two in step.

Quote the handle: YAML reads an unquoted leading `@` as a reserved
indicator and fails.

`.ai/config.yml` lives on the `ai` branch. A checkout without the `.ai`
worktree has no config, which readers treat like an empty one.

## .ai/arcana.token (not config, not committed)

The Arcana session hooks (`arcana hook`, installed by `arcana setup`)
create `.ai/arcana.token` on first use: the owner token that proves to
this machine's bus that the handle's registration is this project's, so
re-registering it answers "yours" instead of "already registered". It is
machine-local: `.ai/.gitignore` lists it (see `assets/gitignore`), and the
code checkout ignores `.ai/` as a whole. Never commit it.

## Changing the schema

Add a key by documenting it here first (type, default, meaning), then use
it. Don't change what an existing key means; add a new one instead, so
older tools keep working.

## Reading it from Crystal

```crystal
require "yaml"

# .ai/config.yml; every key optional, unknown keys ignored
struct AiConfig
  include YAML::Serializable

  struct Arcana
    include YAML::Serializable
    getter handle : String? = nil
  end

  getter arcana : Arcana? = nil

  def self.load(dir = ".ai") : AiConfig
    path = File.join(dir, "config.yml")
    from_yaml(File.exists?(path) ? File.read(path) : "{}")
  end

  def arcana_handle : String?
    arcana.try(&.handle)
  end
end

AiConfig.load.arcana_handle # => "@oyl", or nil without a config or key
```

Tested with Crystal 1.21: a full config, one without the key, and a missing
file give `"@oyl"`, `nil` and `nil`.
