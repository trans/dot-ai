# Records

Records are the curated knowledge taken from transcripts: notes on what was
decided, found, changed or left open; summaries of stretches of
conversation; memories an agent chose to keep, with citations of the
entries they rest on; and whatever other kinds a runtime keeps (Justice's
concerns, file references). Each points back at its evidence by E-number.

They are committed one file per version, so any clone can rebuild its own
index of them. A runtime's database is only that index.

## Files

```
records/<handle>/<YYYY-MM>/N3.md       version 1
records/<handle>/<YYYY-MM>/N3.2.md     version 2: an edit, new tags or links
records/<handle>/<YYYY-MM>/N3.3.md     version 3: removed
```

- `<handle>` is the author's (see [Identity](identity.md)); `<YYYY-MM>` the
  month of the record's `at` (`undated` without one); the name is the id
  without its handle, then `.<version>` from version 2 on.
- **Never rewritten, never deleted.** A change is a new version, and the
  version with the highest number is the record. A removal is a version
  with `removed: true`, after which the record has no more versions.
- **Only the author writes a record's versions,** under their own handle, so
  two machines or two people never write the same file.

## The format

Front matter between `---` lines, one field per line, each value as JSON
(which is also YAML, but reads back exactly); then the body.

```text
---
id: "N3@trans"
user: "trans"
machine: "neo14"
at: "2026-10-12T09:00:00Z"
scope: "project"
kind: "note"
data: {"kind":"decision","from":12,"to":14,"quote":"stateless is cleaner"}
links: {"cites":["CI4@trans"]}
tags: ["auth"]
body: "text"
---
The user chose JWT over server sessions.
```

| Field | Meaning |
|---|---|
| `id` | The record's id, `<code><n>@<handle>` (see [Identity](identity.md)) |
| `user`, `machine`, `at` | Who made it, on which machine, and when (RFC 3339, UTC) |
| `scope` | Where it holds (below) |
| `kind` | The kind's name, as the runtime that owns it declared it (`note`, `summary`, `memory`) |
| `version` | From version 2 on |
| `removed` | `true` on a removal |
| `data` | The kind's other fields, as a JSON object. E-numbers in it (`from`, `to`) are in the author's stream. |
| `links` | Links to other records, by relation: `{"cites": ["CI4@trans"]}`. Targets are ids, always with their handle. |
| `tags` | Labels, sorted |
| `body` | Which field of the record the body holds (`text`, `content`) |

Fields come in this order and are left out when empty. The body is the text
after the closing `---` line, less one final newline; a record whose kind
has no text field has no body.

## Scope

Every record says where it holds:

- `project`: wherever the code is. Decisions, findings about the code,
  changes. The default.
- `machine`: only on the machine where it was learned. Its shell, paths,
  installed tools, local services.
- `user`: one person's preferences.

Scope is a label, not a filter. Search shows every record, every person's
and every machine's, labelled with whose it is and where it was made, and a
machine-scoped record from another machine says it may not hold here. What
a runtime puts in an agent's context window by itself (the dialog it
reloads, the summaries before it) is the agent's own person's.

## Reading

A reader builds its view from the newest version of each id: created,
changed, or (for `removed: true`) gone. Reading only the files added since
the last read is enough to stay current, since files never change once
written. A runtime that numbers records must continue each author's
sequence for a code past the highest number it has read.
