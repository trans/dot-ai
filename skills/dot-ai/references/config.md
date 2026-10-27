# .ai/config.yml

Settings read by AI agents (through the dot-ai skill) and by tools. YAML,
because Crystal's standard library reads it (it has no TOML). Every key is
optional, and readers ignore keys they don't know.

```yaml
handle: oyl         # this project's handle: other agents write to @oyl
description: >      # what this project's agent does, for other agents
  The agent for Oyl, a ...
mail:
  review: triage    # or "all": every outbound message waits for approval
  follow: ["#arcana.releases"]  # topics whose new posts the agent is told of
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
| `handle` | string | the directory's name | This project's handle: other projects' agents send mail to `@` plus it (`@oyl`), whatever carries the mail (local delivery, the Arcana bus). Short, lowercase, letters, digits and `-`. Without one, the project directory's name, folded into a handle (`Silicon.Circus` gives `silicon-circus`). |
| `description` | string | none | One or two sentences on what this project's agent does, for other agents: Arcana's directory listing, an overseer looking over its projects. `>` folds a multi-line value into one paragraph. |
| `mail.review` | string | `triage` | Which outbound mail waits for the user's approval. `triage`: the lead agent decides per message, sending routine mail to the outbox and holding the rest in drafts. `all`: every message waits in drafts. |
| `mail.follow` | list of strings | none | The topics this project follows, by address (`#arcana.releases`, quoted: YAML reads an unquoted `#` as a comment). The carrier tells its agents of new posts in them. |
| `transcript.encrypt` | boolean | `false` | Encrypt committed transcripts on the `ai` branch with git-crypt (GPG mode), on top of redaction. Losing every key loses them, so keep two GPG keys, one offline. |
| `users.<handle>` | map | none | A person working in this project, by handle (short, lowercase, letters, digits and `-`): `name`; `emails`, every address they commit with; and `aliases`, handles they used before this one (ids under them stay theirs). A person's handle is the entry whose `emails` include their git `user.email`; unregistered, it's their email's local part. Records and transcript entries carry it (`N17@trans`, `E1043@trans`), shown without it to its owner. Each contributor adds their own entry; a handle already registered to someone else's emails is taken. |
| `copious` | map | none | Settings for tools built on Copious (ipck), by path: `plugins`, `memory.curate`, `orchestrator.max_depth`, `permissions.allow`, and so on; copious's README ("Settings") lists them. Each machine can override them in its own `.var/ai/config.yml` (the same shape, never committed); `ipck config set` writes there. |
| `transcript.redaction` | string | `standard` | What the AI redaction pass removes before transcripts are committed. `standard`: credentials, contact details (emails, phone numbers, street addresses), internal hosts and URLs, and the contents of private files from outside the project; names stay. `strict`: also people's names, other people's quoted words, and remarks not meant for others. Secrets are masked at every level. |

The dot-ai spec (the user's `dot.ai` repository, `spec/config.md`) is the
normative version of this table; keep the two in step.

Write the handle without the `@` (`handle: oyl`). Written with it, it must
be quoted: YAML reads an unquoted leading `@` as a reserved indicator and
fails.

Per-person settings that hold across projects live in git config instead:
`ai.machine`, this machine's name; `ai.path`, the directories to search
for projects when delivering mail (multi-valued:
`git config --global --add ai.path ~/Projects`), the first of which keeps
the topics; and `ai.carrier`, what carries the mail (`local`, dot-ai-mail,
when unset; or `arcana`).

`.ai/config.yml` lives on the `ai` branch. A checkout without the `.ai`
worktree has no config, which readers treat like an empty one.

## .ai/arcana.token (not config, not committed)

The Arcana session hooks (`arcana hook`, installed by `arcana setup`)
create `.ai/arcana.token` on first use: the owner token that proves to this
machine's bus that the registration under the project's address is this
project's, so re-registering it answers "yours" instead of "already
registered". It is machine-local: `.ai/.gitignore` lists it (see
`assets/gitignore`), and the code checkout ignores `.ai/` as a whole. Never
commit it.

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

  getter handle : String? = nil
  getter description : String? = nil

  def self.load(project_dir = ".") : AiConfig
    path = File.join(project_dir, ".ai", "config.yml")
    from_yaml(File.exists?(path) ? File.read(path) : "{}")
  end

  # The project's mail address: @ plus its handle, or its directory's name
  def address(project_dir = ".") : String
    name = handle.try(&.lchop('@').strip).presence ||
           File.basename(File.expand_path(project_dir)).downcase.gsub(/[^a-z0-9-]+/, "-").strip('-')
    name = "agent-#{name}" unless name =~ /\A[a-z]/
    "@#{name}"
  end
end

AiConfig.load.address # => "@oyl"
```

Tested with Crystal 1.21: `handle: oyl` and `handle: "@oyl"` both give
`"@oyl"`; with no key or no config, a directory `Silicon.Circus` gives
`"@silicon-circus"` and `2048` gives `"@agent-2048"`.
