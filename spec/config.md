# Config

## `.ai/config.yml`

Settings for the agents and tools working in the project. YAML; every key is
optional, and readers ignore keys they don't know. People edit it by hand
and commit it, as a change everyone gets; tools read it and never rewrite
it, so its comments survive.

```yaml
handle: oyl           # the project's handle: its agents' mail address is @oyl
description: >        # what the project's agent does, for other agents
  The agent for Oyl, a ...
mail:
  review: triage      # or "all": every outbound message waits for approval
  follow: ["#arcana.releases"]  # topics whose new posts the agent is told of
transcript:
  encrypt: false      # true: also encrypt committed transcripts (git-crypt)
  redaction: standard # or "strict"
users:                # the people working here, by handle
  trans:
    name: Thomas Sawyer
    emails: [transfire@gmail.com]
copious:              # one tool's own settings, under its name
  memory: {curate: true}
```

| Key | Type | Default | Meaning |
|---|---|---|---|
| `handle` | string | the directory's name | The project's handle (see [Identity](identity.md)): short, lowercase, letters, digits and `-`, starting with a letter. Its agents' mail address is `@` plus it (`@oyl`), whatever carries the mail. It may be written with the `@`, quoted then: YAML reads an unquoted leading `@` as a reserved indicator. |
| `description` | string | none | One or two sentences on what the project's agent does, for other agents (a directory listing, an overseer's view). |
| `mail.review` | string | `triage` | Which outbound mail waits for the user (see [Mail](mail.md)). `triage`: the lead agent decides per message. `all`: every message waits. |
| `mail.follow` | list of strings | none | The topics the project follows, by address (`#arcana.releases`, quoted: YAML reads an unquoted `#` as a comment). The carrier tells its agents of new posts in them (see [Mail](mail.md)). |
| `transcript.redaction` | string | `standard` | What the AI pass removes before transcripts are committed: `standard` or `strict` (see [Protection](protection.md)). A tool that doesn't know the level given must use the strictest it knows. |
| `transcript.encrypt` | boolean | `false` | Also encrypt committed transcripts with git-crypt (see [Protection](protection.md)). |
| `users.<handle>` | map | none | A person working on the project, by handle (see [Identity](identity.md)): `name`; `emails`, every address they commit with; and `aliases`, handles they used before this one. Each person adds their own entry. |
| `<tool>` | map | none | A tool's own settings, under its name (`copious:`). The tool documents its keys. |

## `.var/ai/config.yml`: this machine's settings

The same shape, in the code checkout's `.var/ai/` (see [Layout](layout.md)),
never committed. A tool that reads its settings from `.ai/config.yml` should
also read them from here, the machine's value winning where both set a key.
Tools may write this file (`ipck config set` does); people shouldn't need to
keep comments in it.

Project-wide keys (`handle`, `description`, `mail`, `transcript`, `users`)
are read only from `.ai/config.yml`: they are agreements between everyone
working on the project, not one machine's choice.

Per-person settings that hold across projects belong in git config, not
here: the machine's name (`ai.machine`, see [Identity](identity.md)), where
to look for projects (`ai.path`) and what carries their mail
(`ai.carrier`, see [Mail](mail.md)), and the person's own name and email.

`ai.runner` (multi-valued) names the runners the person allows, the
first being the runner for sessions started without one (see
[Mail](mail.md), Runners).

Read `ai.path`, `ai.carrier` and `ai.runner` from the person's own git
config only:
`git config --global` (which takes in `$XDG_CONFIG_HOME/git/config` as
well), or `git config --system` where that sets none. Never from a
repository's own config, which a plain `git config --get` lets win: one
repository's `ai.carrier` would hand that project's mail to another
carrier, or to none, while every other project's went on as before. A
tool that finds one of them set in a repository's config warns, naming
the repository, and goes on as if it weren't there.

## Carriers' own files

A mail carrier may keep machine-local files in `.ai/`, listed in the
branch's `.gitignore`. Arcana's session hooks keep `.ai/arcana.token`, the
owner token proving to this machine's bus that the registration under the
project's address is this project's, and `.ai/arcana.key`, the project's
private key, which proves the same by signing. Never commit them.

## Changing the schema

Document a key here (type, default, meaning) before using it. Don't change
what an existing key means; add a new one, so older tools keep working.
