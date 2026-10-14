#!/usr/bin/env python3
"""Bring projects' .ai/ directories up to dot-ai draft 0.3.

For each project found (a directory holding .ai/, searched for the way mail
delivery searches, see spec/mail.md):

  - config.yml: arcana.handle and arcana.description become the top-level
    handle (without the @) and description;
  - mail: outbound files in sent/, drafts/ and outbox/ are renamed time
    first, <YYYYMMDD-HHMMSS>Z-<address>--<topic>.md (a sent file's time is
    its Sent: line's, a draft's its modification time), and
    mail/received/ is added;
  - .gitignore: the intake/ lines go, and mail/inbox/ is ignored;
  - .ai/intake/ moves to the project's own intake/, with outtake/ beside
    it, each ignoring itself with a .gitignore of `*`.

Without --apply it only prints what it would do. With --commit it also
commits, on a project's ai branch, the files it changed there, when .ai/ is
a worktree or repository of its own and nothing it touches was already
staged or modified. Run it again and it finds nothing left to do.

Usage: upgrade-to-0.3.py [--apply] [--commit] [--no-config] [ROOT ...]
The roots default to git config's ai.path.
"""

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

MAX_DEPTH = 4
NEW_NAME = re.compile(r"^\d{8}-\d{6}Z-")
OLD_OUTBOUND = re.compile(r"^(?P<addr>[^/]+?)--(?P<date>\d{4}-\d{2}-\d{2})-(?P<topic>.+)\.md$")
SENT_TIME = re.compile(
    r"(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?) ?(Z|[+-]\d{2}:?\d{2}|[A-Z]{3,4})?(?:\s|$)"
)
ZONES = {"Z": 0, "UTC": 0, "GMT": 0, "EST": -5, "EDT": -4, "CST": -6, "CDT": -5, "MST": -7, "MDT": -6, "PST": -8, "PDT": -7}
PLAIN_HANDLE = re.compile(r"^[a-z][a-z0-9-]*$")
YAML_WORDS = {"y", "yes", "n", "no", "true", "false", "on", "off", "null"}

# The template's comments, as 0.3's template words them
OLD_COMMENTS = {
    "this project's agent on the Arcana bus": "this project's handle: other agents write to @{handle}",
    "what that agent does, shown to other agents": "what this project's agent does, shown to other agents",
}
INBOX_IGNORE = [
    "# Mail not yet read: machine-local; it's committed under mail/received/ once read",
    "mail/inbox/*",
    "!mail/inbox/.gitkeep",
]
COMMIT_MESSAGE = """dot-ai 0.3: top-level handle, mail named time first, received/ [skip ci]

Done by scripts/upgrade-to-0.3.py in the dot.ai repository: config.yml's
handle and description move to the top level, mail files are renamed time
first (UTC), mail/received/ is added, the inbox is ignored, and intake/
leaves .ai/ for the project's own directory.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
"""


def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True)


class Project:
    def __init__(self, path):
        self.path = path
        self.ai = path / ".ai"
        top = git(self.ai, "rev-parse", "--show-toplevel")
        self.in_git = top.returncode == 0
        self.own_repo = self.in_git and Path(top.stdout.strip()).resolve() == self.ai.resolve()
        self.steps = []  # (what, function)
        self.notes = []  # what's left for a person
        self.stage = []  # paths in .ai/ to stage, added or changed
        self.unstage = []  # paths in .ai/ to stage as removed

    def step(self, what, fn):
        self.steps.append((what, fn))

    def tracked(self, rel):
        return self.own_repo and git(self.ai, "ls-files", "--error-unmatch", "--", rel).returncode == 0


# Finding projects (spec/mail.md: Finding projects)


def find_projects(root):
    found = []

    def walk(d, depth):
        ai = d / ".ai"
        if ai.is_dir() and not ai.is_symlink():
            found.append(d)
        if depth == MAX_DEPTH:
            return
        try:
            entries = sorted(os.scandir(d), key=lambda e: e.name)
        except OSError:
            return
        for e in entries:
            if e.name.startswith(".") or e.name == "node_modules":
                continue
            if e.is_dir(follow_symlinks=False):
                walk(Path(e.path), depth + 1)

    walk(root, 0)
    return found


# config.yml


def split_comment(text):
    """Split `key: value  # comment` into (key and value, comment, the comment's column)."""
    quote = None
    for i, c in enumerate(text):
        if quote:
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "#" and (i == 0 or text[i - 1] in " \t"):
            return text[:i].rstrip(), text[i + 1 :].strip(), i
    return text.rstrip(), None, None


def rewrite_entry_head(key, line, indent):
    head, comment, column = split_comment(line[indent:].rstrip("\n"))
    handle = None
    if key == "handle":
        value = head.split(":", 1)[1].strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        handle = value.lstrip("@")
        shown = handle if PLAIN_HANDLE.match(handle) and handle not in YAML_WORDS else json.dumps(handle)
        head = f"handle: {shown}"
    if comment is None:
        return head + "\n"
    for old, new in OLD_COMMENTS.items():
        if comment.startswith(old):
            comment = new.format(handle=handle) + comment[len(old) :]
    return head + " " * max(1, column - len(head)) + "# " + comment + "\n"


def rewrite_config(text):
    """The config with arcana.handle and arcana.description moved to the top
    level, and the keys moved; None when there's nothing to move (or it isn't
    shaped as expected)."""
    lines = text.splitlines(keepends=True)
    if any(re.match(r"(handle|description)\s*:", l) for l in lines):
        return None
    start = next((i for i, l in enumerate(lines) if re.match(r"arcana\s*:\s*(#.*)?$", l.rstrip("\n"))), None)
    if start is None:
        return None
    end = start + 1
    while end < len(lines) and (not lines[end].strip() or lines[end][0] in " \t"):
        end += 1
    while end > start + 1 and not lines[end - 1].strip():
        end -= 1
    block = lines[start + 1 : end]
    if not any(l.strip() for l in block):
        return None
    indent = min(len(l) - len(l.lstrip(" ")) for l in block if l.strip())

    entries = []  # [key, lines]
    for l in block:
        own_indent = len(l) - len(l.lstrip(" "))
        m = re.match(r"([A-Za-z_][\w-]*)\s*:", l[own_indent:]) if l.strip() and own_indent == indent else None
        if m:
            entries.append([m.group(1), [l]])
        elif entries:
            entries[-1][1].append(l)
        else:
            return None

    moved = [e for e in entries if e[0] in ("handle", "description")]
    kept = [e for e in entries if e[0] not in ("handle", "description")]
    if not moved:
        return None
    out = []
    for key, entry in sorted(moved, key=lambda e: e[0] != "handle"):
        out.append(rewrite_entry_head(key, entry[0], indent))
        out += [l[indent:] if l[:indent].strip() == "" and l.strip() else l.lstrip(" ") for l in entry[1:]]
    if kept:
        out += [lines[start]] + [l for _, entry in kept for l in entry]
    return "".join(lines[:start] + out + lines[end:]), [key for key, _ in moved]


def check_config(old, new):
    """Why the rewrite is wrong, if PyYAML reads it back differently; None if it's right."""
    try:
        import yaml
    except ImportError:
        return None
    try:
        before, after = yaml.safe_load(old) or {}, yaml.safe_load(new) or {}
    except yaml.YAMLError as ex:
        return f"YAML error: {ex}"
    arcana = dict(before.get("arcana") or {})
    want = {k: v for k, v in before.items() if k != "arcana"}
    if "handle" in arcana:
        want["handle"] = str(arcana.pop("handle")).lstrip("@")
    if "description" in arcana:
        want["description"] = arcana.pop("description")
    if arcana:
        want["arcana"] = arcana
    return None if after == want else "the rewrite doesn't read back the same"


def plan_config(p):
    path = p.ai / "config.yml"
    if not path.is_file():
        return
    text = path.read_text()
    rewritten = rewrite_config(text)
    if rewritten is None:
        if re.search(r"^arcana\s*:", text, re.M) and not re.search(r"^handle\s*:", text, re.M):
            p.notes.append("config.yml: an arcana: block the script can't rewrite; move handle and description by hand")
        return
    new, moved = rewritten
    problem = check_config(text, new)
    if problem:
        p.notes.append(f"config.yml: {problem}; left as is")
        return
    keys = " and ".join(f"arcana.{k}" for k in moved)
    p.step(f"config.yml: {keys} {'move' if len(moved) > 1 else 'moves'} to the top level", lambda: path.write_text(new))
    p.stage.append("config.yml")


# Mail


def parse_time(value):
    """A Sent: line's time in UTC: ISO 8601, or `2026-10-13 14:37 EDT` and the like."""
    m = SENT_TIME.match(value)
    if not m:
        return None
    date, clock, zone = m.groups()
    when = dt.datetime.fromisoformat(f"{date}T{clock}")
    if zone is None:
        return when.astimezone(dt.timezone.utc)  # this machine's local time
    if zone in ZONES:
        offset = dt.timedelta(hours=ZONES[zone])
    elif zone[0] in "+-":
        digits = zone[1:].replace(":", "")
        offset = dt.timedelta(hours=int(digits[:2]), minutes=int(digits[2:])) * (1 if zone[0] == "+" else -1)
    else:
        return None
    return when.replace(tzinfo=dt.timezone(offset)).astimezone(dt.timezone.utc)


def sent_time(p, path):
    """When a sent message went: its Sent: line, else when it was committed."""
    for line in path.read_text(errors="replace").splitlines():
        if not line.strip():
            break
        if line.startswith("Sent:"):
            when = parse_time(line[5:].strip())
            if when:
                return when
    if p.tracked(f"mail/sent/{path.name}"):
        added = git(p.ai, "log", "--diff-filter=A", "--format=%cI", "--", f"mail/sent/{path.name}").stdout.split()
        if added:
            return dt.datetime.fromisoformat(added[-1]).astimezone(dt.timezone.utc)
    return None


def plan_mail(p):
    mail = p.ai / "mail"
    if not mail.is_dir():
        for old in ("inbox", "outbox"):
            if (p.ai / old).is_dir() and any(f.name != ".gitkeep" for f in (p.ai / old).iterdir()):
                p.notes.append(f".ai/{old}/ is the layout before mail/; left as is")
        return
    for folder in ("sent", "drafts", "outbox"):
        d = mail / folder
        if not d.is_dir():
            continue
        for f in sorted(d.iterdir()):
            if f.name.startswith(".") or not f.is_file() or NEW_NAME.match(f.name):
                continue
            m = OLD_OUTBOUND.match(f.name)
            if not m:
                p.notes.append(f"mail/{folder}/{f.name}: not named the old way either; left as is")
                continue
            when = sent_time(p, f) if folder == "sent" else None
            if when is None and folder == "sent":
                when = dt.datetime.fromisoformat(m["date"]).replace(tzinfo=dt.timezone.utc)
                p.notes.append(f"mail/sent/{f.name}: no time in its Sent: line or git, so midnight of its date")
            elif when is None:
                when = dt.datetime.fromtimestamp(f.stat().st_mtime, dt.timezone.utc)
            address = m["addr"] if m["addr"].startswith("@") else "@" + m["addr"]
            name = f"{when:%Y%m%d-%H%M%S}Z-{address}--{m['topic']}.md"
            if (d / name).exists():
                p.notes.append(f"mail/{folder}/{f.name}: {name} already exists; left as is")
                continue
            p.step(f"mail/{folder}/{f.name} -> {name}", lambda f=f, to=d / name: f.rename(to))
            if folder == "sent" and p.tracked(f"mail/sent/{f.name}"):
                p.unstage.append(f"mail/{folder}/{f.name}")
                p.stage.append(f"mail/{folder}/{name}")
    waiting = [f for f in (mail / "inbox").glob("*") if not f.name.startswith(".")] if (mail / "inbox").is_dir() else []
    if waiting:
        p.notes.append(f"mail/inbox/ holds {len(waiting)} message(s): process them (read mail now goes to mail/received/)")
    received = mail / "received"
    if not (received / ".gitkeep").exists():
        p.step("add mail/received/", lambda: (received.mkdir(exist_ok=True), (received / ".gitkeep").touch()))
        p.stage.append("mail/received/.gitkeep")


# .gitignore


def plan_gitignore(p):
    path = p.ai / ".gitignore"
    if not path.is_file():
        return
    lines = path.read_text().splitlines()
    drop = {i for i, l in enumerate(lines) if l.strip() in ("intake/*", "!intake/.gitkeep")}
    for i in sorted(drop):
        if i > 0 and lines[i - 1].startswith("#") and i - 1 not in drop and lines[i].strip() == "intake/*":
            drop.add(i - 1)
    out = [l for i, l in enumerate(lines) if i not in drop]
    if (p.ai / "mail").is_dir() and "mail/inbox/*" not in (l.strip() for l in out):
        out += INBOX_IGNORE
    if out == lines:
        return
    text = "\n".join(out) + "\n"
    p.step(".gitignore: drop intake/, ignore mail/inbox/", lambda: path.write_text(text))
    p.stage.append(".gitignore")


# intake/ and outtake/


def remove_old_intake(old):
    keep = old / ".gitkeep"
    if keep.exists():
        keep.unlink()
    if not any(old.iterdir()):
        old.rmdir()


def make_folder(d):
    d.mkdir(exist_ok=True)
    (d / ".gitignore").write_text("*\n")


def plan_intake(p):
    old = p.ai / "intake"
    if not old.is_dir() or old.is_symlink():
        return
    for name in ("intake", "outtake"):
        d = p.path / name
        if d.exists() and not d.is_dir():
            p.notes.append(f"{name} exists in the project but isn't a directory; left as is")
        elif not (d / ".gitignore").exists():
            if d.is_dir():
                p.notes.append(f"{name}/ already exists in the project; it gets a .gitignore of *")
            p.step(f"add {name}/ to the project, ignoring itself", lambda d=d: make_folder(d))
    for f in sorted(old.iterdir()):
        if f.name == ".gitkeep":
            continue
        if (p.path / "intake" / f.name).exists():
            p.notes.append(f".ai/intake/{f.name}: intake/ already has one; left in .ai/intake/")
            continue
        p.step(f"move .ai/intake/{f.name} to intake/", lambda f=f: shutil.move(str(f), str(p.path / "intake" / f.name)))
    p.step("remove .ai/intake/", lambda: remove_old_intake(old))
    if p.tracked("intake/.gitkeep"):
        p.unstage.append("intake/.gitkeep")


# Running


def commit(p):
    for args, paths in ((["rm", "--cached", "-q", "--ignore-unmatch"], p.unstage), (["add"], p.stage)):
        r = git(p.ai, *args, "--", *paths) if paths else None
        if r and r.returncode != 0:
            return f"not committed: git {args[0]} failed: {r.stderr.strip()}"
    r = subprocess.run(
        ["git", "-C", str(p.ai), "commit", "-q", "-F", "-"], input=COMMIT_MESSAGE, capture_output=True, text=True
    )
    if r.returncode != 0:
        return f"commit failed: {r.stderr.strip() or r.stdout.strip()}"
    return "committed " + git(p.ai, "rev-parse", "--short", "HEAD").stdout.strip()


def blocks_commit(p):
    """Why committing here would take in someone else's changes, if it would."""
    if git(p.ai, "diff", "--cached", "--quiet").returncode != 0:
        return "something is already staged in .ai/"
    paths = [x for x in p.stage + p.unstage if (p.ai / x).exists()]
    if paths and git(p.ai, "status", "--porcelain", "--", *paths).stdout.strip():
        return "a file it changes was already modified"
    return None


def show(path):
    home = Path.home()
    return "~/" + str(path.relative_to(home)) if path.is_relative_to(home) else str(path)


def main():
    ap = argparse.ArgumentParser(description="Bring projects' .ai/ up to dot-ai draft 0.3.")
    ap.add_argument("roots", nargs="*", help="directories to search (default: git config ai.path)")
    ap.add_argument("--apply", action="store_true", help="make the changes (otherwise only print them)")
    ap.add_argument("--commit", action="store_true", help="also commit them on each ai branch (implies --apply)")
    ap.add_argument("--no-config", action="store_true", help="leave config.yml alone")
    args = ap.parse_args()
    apply = args.apply or args.commit

    roots = args.roots or git(".", "config", "--get-all", "--type=path", "ai.path").stdout.split("\n")
    roots = [Path(r).expanduser() for r in roots if r.strip()]
    if not roots:
        sys.exit("No directories to search: name some, or set git config ai.path.")

    projects, seen = [], set()
    for root in roots:
        for path in find_projects(root):
            if path.resolve() not in seen:
                seen.add(path.resolve())
                projects.append(Project(path))

    changed = 0
    for p in projects:
        if not args.no_config:
            plan_config(p)
        plan_mail(p)
        plan_gitignore(p)
        plan_intake(p)
        if not p.steps and not p.notes:
            continue
        kind = "ai branch" if p.own_repo else "committed with the code" if p.in_git else "not in git"
        print(f"{show(p.path)} ({kind})")
        for what, _ in p.steps:
            print(f"  {what}")
        for note in p.notes:
            print(f"  ! {note}")
        if not p.steps:
            print()
            continue
        changed += 1
        blocked = blocks_commit(p) if args.commit and p.own_repo and (p.stage or p.unstage) else None
        if apply:
            try:
                for _, fn in p.steps:
                    fn()
            except OSError as ex:
                print(f"  ! stopped: {ex}; nothing committed")
                continue
            if args.commit and p.own_repo and (p.stage or p.unstage):
                print(f"  ! not committed: {blocked}" if blocked else f"  {commit(p)}")
        if p.in_git and not p.own_repo and (p.stage or p.unstage):
            print("  (.ai/ is in the code checkout: commit it there, if it's tracked)")
        print()

    found = f"{len(projects)} project(s) found, {changed} to change."
    if apply:
        print(found + (" Done." if changed else ""))
    else:
        print(found + " Nothing changed: --apply makes the changes, --commit commits them too.")


if __name__ == "__main__":
    main()
