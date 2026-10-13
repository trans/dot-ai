# Memory

`memory/` holds the notes agents keep for each other, written by hand
(by an agent, that is), as opposed to the records a runtime curates (see
[Records](records.md)). They hold what isn't in the code or its history:
where things stand, plans agreed with the user, decisions in progress and
their reasons, lessons that cost something to learn, open issues, the
projects it corresponds with.

- **`memory/README.md` is the index:** a table with one row per note (its
  file and what it holds), and the conventions below, so an agent without
  the dot-ai skill can follow them too.
- **One note per topic** (`status.md`, `release.md`). A new topic gets a new
  note and a row in the index, in the same commit; otherwise the note that
  covers the topic is updated.
- **Reference material** kept whole (a spec, a design, a patch) is a file of
  its own, with a row in the index.
- **Dated:** `*Updated YYYY-MM-DD*` under each title, and absolute dates
  inside, never "today". Commits are cited by hash, so claims can be
  checked.
- **Decisions say who made them:** "the user chose X (2026-10-07)", so a
  later agent knows the question is settled.
- **States are marked plainly** (**Open**, **Fixed in `abc1234`**) and kept
  current.
- **Project facts only.** What holds on one machine (paths, hardware,
  installed tools) doesn't belong here: the branch travels and the machine
  doesn't.
- **Settled knowledge moves out:** what anyone working on the code should
  know belongs in the project's own docs, with a pointer left here.
- **Never credentials or keys.** On a public repository, also nothing
  private: no personal details, internal URLs, or other people's words
  verbatim. Notes aren't run through the AI pass (see
  [Protection](protection.md)); their authors keep them clean.
