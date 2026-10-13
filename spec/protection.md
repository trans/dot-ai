# Protection

**Nothing is committed to `.ai/` unprotected.** The branch may be public, or
become public, and a pushed commit can't be taken back: a private
repository keeps a leaked key in its history too. Public transcripts are
wanted (to show how a project was built), as well as backup and moving
between machines, so protection is what makes committing them possible.

Two layers apply to everything a runtime commits, and a third is optional:

1. **The scrub** masks secrets. Deterministic, always.
2. **The AI pass** replaces private spans, at the project's level.
3. **Encryption** (`transcript.encrypt`) encrypts committed transcripts on
   top of both.

## The scrub

Applied before anything is written, even to this machine's own
`.var/ai/transcript/`, and again to everything committed. It masks:

- the values of secret environment variables: names ending in `API_KEY`,
  `TOKEN`, `SECRET`, `PASSWORD` or `PASSWD`, values of at least 8
  characters (so short values don't mask ordinary words);
- the API keys the runtime is configured with;
- token formats: `sk-…` and `sk-ant-…`, `ghp_…` (and `gho_`, `ghu_`,
  `ghs_`, `ghr_`), `github_pat_…`, `AKIA…`, `xox…`;
- private-key blocks (`-----BEGIN … PRIVATE KEY-----` to its end);
- passwords in URLs (`https://user:…@host`).

Each becomes `[redacted: <what>]`: `secret`, `api key`, `github token`,
`aws key`, `slack token`, `private key`, `password`.

## The AI pass

A model reads each batch of entries and lists the spans to remove; each is
replaced, everywhere in the batch, by `[redacted: <label>]`. Labels:
`email`, `phone`, `address`, `host`, `url`, `path`, `credential`, `name`,
`quote`, `private`.

`transcript.redaction` in `.ai/config.yml` sets what it removes:

| Level | Removes |
|---|---|
| `standard` (default) | Credentials the scrub missed; contact details (email addresses, phone numbers, street addresses); internal host names, IP addresses, and URLs that aren't public websites; the contents of private files from outside the project (home-directory dotfiles, `~/.ssh`, system configuration). People's names stay. |
| `strict` | All of `standard`, and: people's names (not public figures, not software); other people's words (quoted emails, chat messages, documents from anyone but the user and the agent); remarks clearly not meant for others (personal matters, opinions about named people). |

- **When unsure, redact.** A miss on a public branch is permanent.
- **Every form:** a span is listed in every form it appears in (an address
  written in full and in part; at `strict`, "Jane Doe" and "Jane").
- **Emails the repository already publishes stay, at `standard`:** the
  addresses of its commits' authors and committers, and the user's own git
  email. This is a deterministic check, not the model's call. Every other
  address is redacted.
- **What it covers:** each entry's content, and its `meta` attribute. JSON
  (a tool call's input, `meta`) is redacted within its strings, so it stays
  valid JSON. The other attributes are the runtime's own (times, types,
  names of tools) and are copied as they are.
- **A tool that doesn't know the configured level** must apply the
  strictest it knows.

## Order and completeness

- A committed transcript holds only entries that have been through both
  layers, in order, as far as they have got. An entry is never copied
  ahead of one before it in the same file.
- A batch the model can't redact (no usable answer) is tried again later.
  After three failures its entries are **withheld**: each is committed as a
  marker with only its number (`<E12 withheld="redaction failed"/>`), the
  user is told, and the local file is kept on the machine for good, as the
  only copy of them.
- A file's **header** is copied with the scrub only. It names the person by
  their git identity, which the repository's commits already publish.
- **Redaction is final.** Once the local files are pruned, the committed
  copy is the record for everyone, the machine that wrote it included.

## Records

Records are committed with their transcript's protection: before a version
is written to `.ai/records/`, its text fields (the body, a quote, a title)
must be scrubbed and redacted at the project's level, like transcript
entries. A record that can't be redacted yet waits; it isn't written
unprotected.

## Encryption

With `transcript.encrypt: true`, committed transcripts are also encrypted on
the branch with git-crypt, in GPG mode: plain text on unlocked machines,
ciphertext everywhere else. It doesn't relax redaction.

- **Set up** in the `.ai` worktree: `git-crypt init`, a `.gitattributes`
  with `transcript/** filter=git-crypt diff=git-crypt`, and
  `git-crypt add-gpg-user` for each key.
- **A runtime must not commit transcripts** unless git-crypt's filter is
  configured in `.ai`, applies to `transcript/`, and the worktree is
  unlocked. It says why it isn't copying, and keeps the local files.
- **Unlocking** happens inside the worktree (`cd .ai && git-crypt unlock`),
  since git-crypt keeps its key in the worktree's own git directory.
  Re-adding the worktree means unlocking again. Transcript files that look
  like binary mean the worktree is locked.
- **Losing every key loses the encrypted transcripts.** Add at least two
  GPG keys, one kept offline, and keep an exported key
  (`git-crypt export-key`) in a password manager.
- **Revoking someone's access doesn't re-encrypt history.**

## Backstop

On GitHub, push protection blocks known secret formats on public
repositories. It's a last line, not a layer: it doesn't know private
details, and it doesn't apply to every host.
