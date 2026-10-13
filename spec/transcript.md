# Transcripts

A transcript is the record of an agent session: every message, reply, tool
call and result, in order, each under its id. It is written as the session
goes, and it is the system of record: anything else (notes, summaries, a
search index) is derived from it and points back at it by E-number.

## Where

| Copy | Where | What |
|---|---|---|
| As written | `.var/ai/transcript/` | Secrets masked, nothing else removed. Never committed. |
| Committed | `.ai/transcript/` | Protected (see [Protection](protection.md)): the record everyone reads. |

Both copies of a file have the same name. A committed file only ever grows,
and holds the entries of its local file, in order, as far as they have been
protected. A reader merges the two (see Reading).

## Files

Each run of a runtime writes a **main file** for its conversation and one
**subagent file** per subagent it starts, since subagents running at the
same time would otherwise interleave.

```
2026-10-12T012036-neo14-e400.md                          main
2026-10-12T012036-neo14-e400.spawn-5f0c2a9e1b7d4c3a.md   a subagent
```

- **Main:** `<started>-<machine>-<random>.md`. `started` is the UTC time,
  `YYYY-MM-DDTHHMMSS`; `machine` is the machine's name (see
  [Identity](identity.md)); `random` is four hex digits. Names sort in time
  order.
- **Subagent:** the main file's name without `.md`, a `.`, the subagent's
  key (its session's key, any `/` written as `~`), then `.md`. A name with no `.` before `.md`
  is a main file.
- A runtime should start a new main file once one passes a size limit (the
  new file has its own header).
- Text is UTF-8, lines end with `\n`.

## The header

A file's first line says what it is:

```text
<transcript project="ipck" started="2026-10-12T01:20:36.625Z" machine="neo14" handle="trans" user="Thomas Sawyer &lt;transfire@gmail.com&gt;" os="Linux" shell="zsh" git="266d5b4"/>
```

| Attribute | In | Meaning |
|---|---|---|
| `project` | main | The project's directory name |
| `started` | main | When the file was started (RFC 3339, UTC) |
| `key`, `main` | subagent | The subagent's key, and its main file's name |
| `machine` | both | The machine's name |
| `handle` | both | Whose stream it is: their handle |
| `user` | both | Git's `Name <email>` (or whichever part is known) |
| `os`, `shell` | both | `Linux`, `macOS`, `Windows`; the shell's name |
| `git`, `dirty` | main | The code's HEAD (short hash) when the file started, and `dirty="true"` if tracked files differed from it |

A file's owner is its header's `handle`; with none, the handle its `user`'s
email would get (see [Identity](identity.md)). A file whose header names
neither (from before headers did) counts as everyone's.

## Entries

```text
<E1042 at="2026-10-10T14:03:22.120Z" by="user" type="user_message" bytes="45">
Create a README for the test project, please.
</E1042>

<E1051 at="2026-10-10T14:05:02.004Z" git="3f1a9c2" dirty="true"/>

```

An entry is an opening tag on a line of its own, its content, and a closing
tag, followed by a blank line. The tag's name is the entry's E-number.

- **`bytes`** is the content's length in bytes, and comes last. A reader
  takes exactly that many bytes after the opening line, whatever they hold,
  then expects `\n`, the closing tag `</E1042>` on its own line, and a blank
  line. Content is stored as is (Markdown, JSON, command output) and never
  escaped: a tag quoted inside it is just content.
- **A marker** is an entry with no content, self-closing (`<E1051 …/>`).
- **Attributes** are `name="value"`, names lowercase letters and `-`, each
  preceded by one space. In values, `&`, `"`, `<`, `>` and newline are
  written `&amp;`, `&quot;`, `&lt;`, `&gt;` and `&#10;`.
- Readers must ignore attributes they don't know, so runtimes can add their
  own.

### Attributes

| Attribute | Meaning |
|---|---|
| `at` | When (RFC 3339, UTC, milliseconds) |
| `by` | Who: `user`, `leader`, an agent, a tool |
| `type` | `user_message`, `agent_response`, `tool_use`, `tool_result`, `lifecycle`, `system`, `memory` |
| `subtype`, `name` | A finer kind (`turn_end`, `spawn_start`); the tool's name for a call or result |
| `key`, `level` | A subagent's key and nesting depth (absent in the main conversation) |
| `parent`, `pair` | The entry this one belongs under; the entry it answers (a result's call, a reply's message), as `E1042` in the same stream |
| `api-id` | The model provider's id for a tool call, on the call and its result |
| `is-error` | `true` on a tool result that failed |
| `pending` | `true` on an entry waiting for something (an async result) |
| `meta` | Any other data about the event, as JSON |
| `transcript` | On a subagent's start and end markers in its parent's file: the subagent file's name |
| `git`, `dirty` | A marker: the code's HEAD changed, or tracked files began or stopped differing from it |
| `torn` | `true` on an entry a crash cut off, closed with whatever of it was written |
| `withheld` | A marker in a committed copy: the entry couldn't be protected, so only its number is committed (see [Protection](protection.md)) |

### Content

- A message or reply: its text.
- A tool call: its input, as JSON.
- A tool result: its output, as the runtime kept it. Large output is
  referenced where it can be had again exactly (a committed file:
  `read src/x.cr:1-200 @ 2e40626 (not copied: git show 2e40626:src/x.cr)`),
  and otherwise capped to its first and last lines with a note of what was
  left out (`[… 3214 lines omitted …]`).
- What the model was shown but that can be rebuilt (rendered views, panels)
  isn't logged; the operations that made it are.

## Numbering

E-numbers are per person: each numbers their own stream, across all their
files and machines.

- Numbers increase in the order entries are written, and within a file,
  entries are in number order. A subagent's entries are numbered from the
  same stream, so they interleave with the main file's by number.
- Before writing, a runtime must continue past the highest number in the
  person's files that it can see: its local ones and the committed ones,
  after pulling the branch.
- Gaps are allowed (a crash between taking a number and writing it).
- The same person on two machines, writing without pulling in between, can
  write the same number twice. The two are in different files, named after
  their machines, so the collision can be detected. A reader resolves it to
  the file whose name sorts last.

## Reading

- **The record** is the committed files and the local ones, by name: a file
  in both is one file, and an entry in both is the local one (the original).
  Once local files are deleted, the committed ones are all there is.
- **Whose:** an id with no handle is looked up in the reader's own files;
  `E1043@pat` in pat's (by header).
- **An entry:** `grep -rn '^<E1043 ' .ai/transcript .var/ai/transcript`, in
  the right person's files. A quoted copy inside a later entry's content
  can match too; parsing the file from the top tells them apart.
- **A range** (`E1042-E1061`) reads the main files: a subagent's work shows
  as its start and end markers, which name its file.
- **An unfinished last entry** (no closing tag, or fewer bytes than
  `bytes`) is being written, or was cut off by a crash. Readers leave it
  out. At startup a runtime closes a torn entry in its own files: whatever
  of it was written, with `torn="true"`; a last line that isn't an entry at
  all is dropped.
