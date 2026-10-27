# Mail between machines over git

*Idea, 2026-10-27. Not built, nothing decided. From the user's question
whether mail could be delivered by git pulls and pushes.*

Local delivery reaches only one machine (README, Open questions). In
[Mail](../spec/mail.md)'s terms, mail between machines needs a carrier that
reaches them. Arcana could be one, but it needs a daemon both machines can
reach, with networking and authentication. Git needs only the access the
user already has.

## A post office

A private repository that all of one user's machines pull from and push to
(`trans/ai-mail`, say), named in git config. It's the carrier's store, never
an agent's: agents still write to their outbox and read their inbox, and
notice no difference.

- **Sending.** dot-ai-mail delivers to the projects on this machine as it
  does now. A message whose recipient it can't find here is committed to
  the post office under `to/<address>/`, already named and headed as an
  inbox file, and pushed; then the original is filed under `sent/`. Mail
  whose recipient is on this machine never goes through the post office.
- **Receiving.** Each run pulls. A message under `to/<address>/`, where this
  machine has that address's project, is claimed by moving it to
  `taken/<machine>/` (`ai.machine`) and pushing; once its inbox file is
  written, a later commit removes it from there. A run that stopped between
  the two finds it still under `taken/` and delivers it again, which the id
  check in Delivery catches, so delivery stays at least once.
- **Races.** Git refuses a push that isn't based on the newest commit, so
  the push is the lock. Of two machines claiming one message, or numbering
  one post, the one whose push lands wins; the other pulls and tries again.
  A project cloned on two machines gets each message on whichever claims it
  first.
- **Topics.** Kept in the post office's `topics/<name>/` instead of the
  topic home, numbered as now, with the number taken by the push.
- **Timing.** A pull at every hook (session start, each turn's end, session
  end), with no throttle: a turn takes minutes, so that's one fetch, about a
  second, per turn. A message reaches another machine at the sender's next
  hook and is noticed at the recipient's next one. An idle session hears
  nothing until it's prompted, as with local mail.

## Not the projects' own repositories

- **Into the recipient's repository:** that's writing into another
  project's `.ai/`, and the inbox isn't committed, so it would need a
  committed folder of its own (the README's first idea).
- **From the senders' `sent/`:** every message is already committed there,
  so a recipient could fetch the senders' repositories and pick out what's
  addressed to it. But every machine would have to watch every repository,
  delivery would wait for the sender to commit and push, and some of them
  are public.

## What it would change

- dot-ai-mail gets a remote and could be the one carrier everywhere: Arcana
  keeps services and live sessions, and `ai.carrier` might never be set.
- The spec gains the post office's git config key, its layout, and a
  `Via:` value for mail that came through it.
- It would come after dot-ai-mail 0.3, which has topics on one machine.

## Open

- The config key's name, and `Via: git` or `Via: local`.
- Pruning: the history keeps every message; only the tree is cleared.
- The post office is private, but GitHub holds a copy of all the mail.
