# Setting up .ai/ by hand

`dot-ai init` does all of this. These are its steps, for when it can't
run, or stopped partway and you're finishing what it started.

## A new .ai/

1. In the code checkout, add `/.ai/` to `.gitignore` and commit that alone.
2. Create the branch and its worktree: `git worktree add --orphan -b ai .ai`.
   Before git 2.42, which lacks `--orphan` there: `git worktree add --detach
   .ai`, then `git -C .ai checkout --orphan ai` and `git -C .ai rm -rfq .`
   (that empties the new worktree, not the checkout).
3. Create `.ai/.gitignore` from `assets/gitignore`, `.ai/config.yml` from
   `assets/config.yml` with `PROJECT` replaced by the handle, and
   `.ai/memory/README.md` from `assets/memory-README.md`. The README
   restates the skill's conventions, so agents without the skill can
   follow them too.
4. Create a `.gitkeep` in `.ai/mail/drafts/`, `mail/outbox/`, `mail/sent/`,
   `mail/inbox/` and `mail/received/`. (The `.gitignore` keeps the contents
   of drafts, outbox and inbox out of commits, but not their `.gitkeep`.)
   In the project's own directory, create `Intake/` and `Outtake/`, each
   with a `.gitignore` containing only `*`.
5. Commit on the branch.

On another clone, `git worktree add .ai ai` checks the branch out, or
`git worktree add --track -b ai .ai origin/ai` when only the remote has it.

## Moving an existing .ai/ onto its own branch

For a project whose `.ai/` is still committed with the code:

1. Make the branch from the notes' history:
   `git subtree split --prefix=.ai -b ai`. The branch holds `.ai/`'s
   contents at its root, with every commit that touched them.
2. In the code checkout: `git rm -r --cached .ai`, add `/.ai/` to
   `.gitignore`, and commit. The old notes stay in the code's history.
3. Move the old directory aside and check the branch out:
   `mv .ai .ai.old && git worktree add .ai ai`. Copy `arcana.token` and
   `arcana.key` (if any) across from `.ai.old/`, and move anything in its
   `intake/` to the project's `Intake/` (the skill's Intake and Outtake);
   they were never committed.
4. On the branch: add `.gitignore` from `assets/gitignore` and the `mail/`
   folders with their `.gitkeep`. Messages in the old `inbox/` haven't been
   read yet: take them out of git (`git -C .ai rm -r --cached inbox`), move
   them into `mail/inbox/`, and commit. Then process them as usual.
5. Push the branch if the user agrees, then remove `.ai.old/` once
   everything is across.
