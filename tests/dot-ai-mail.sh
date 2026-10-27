#!/bin/sh
# Tests for skills/dot-ai/scripts/dot-ai-mail: builds projects in a temporary
# directory and checks delivery, recovery and the hooks. Run: just test
SH=${SH:-sh} # the shell to test under: SH="zsh --emulate sh", say
M=$(cd "$(dirname "$0")/.." && pwd -P)/skills/dot-ai/scripts/dot-ai-mail
T=$(mktemp -d "${TMPDIR:-/tmp}/dot-ai-mail-test.XXXXXX") || exit 1
trap 'rm -rf "$T"' EXIT
P=$T/projects
printf '[ai]\n\tpath = %s\n' "$P" >"$T/gitconfig"
GIT_CONFIG_GLOBAL=$T/gitconfig XDG_RUNTIME_DIR=$T/run
export GIT_CONFIG_GLOBAL XDG_RUNTIME_DIR
mkdir -p "$T/run"
unset CLAUDE_PROJECT_DIR PLUGIN_ROOT

failed=0
ok() { printf 'ok   %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  failed=1
}
check() { if eval "$2"; then ok "$1"; else fail "$1"; fi; }
project() {
  mkdir -p "$P/$1/.ai/mail/inbox" "$P/$1/.ai/mail/outbox" "$P/$1/.ai/mail/sent" "$P/$1/.ai/mail/received"
  [ -n "$2" ] && printf '%s\n' "$2" >"$P/$1/.ai/config.yml"
  :
}
count() { ls "$1" 2>/dev/null | wc -l | tr -d ' '; }

project alpha 'handle: alpha   # a comment'
project beta 'handle: "@beta"'
project group/Gamma.Site ''
project twin1 'handle: twin'
project twin2 "handle: 'twin'"
project .hidden/eps 'handle: eps'
mkdir -p "$P/delta/.ai" && printf 'handle: delta\n' >"$P/delta/.ai/config.yml"
mkdir -p "$P/.ai" # the topic home: the first ai.path directory
ln -s alpha "$P/link"
A=$P/alpha/.ai/mail B=$P/beta/.ai/mail

# Finding
check "find: quoted handle" '[ "$($SH "$M" find beta)" = "$P/beta" ]'
check "find: folded directory name" '[ "$($SH "$M" find gamma-site)" = "$P/group/Gamma.Site" ]'
check "find: two projects, one address" '! $SH "$M" find twin 2>/dev/null'
check "find: hidden directories and links skipped" '! $SH "$M" find eps 2>/dev/null && [ "$($SH "$M" find | grep -c "/alpha$")" = 1 ]'

# Delivering
printf 'By: a helper\n\nHello.\n' >"$A/outbox/20261015-140000Z-@beta--hello.md"
printf 'no newline' >"$A/outbox/20261015-140100Z-@beta.md"
printf 'x\n' >"$A/outbox/20261015-140200Z-@twin--dup.md"
printf 'x\n' >"$A/outbox/20261015-140300Z-#news--post.md"
printf 'x\n' >"$A/outbox/20261015-140400Z-@delta--nomail.md"
printf 'x\n' >"$A/outbox/old-name.md"
out=$(cd "$P/alpha" && $SH "$M" deliver)
status=$?
check "deliver: fails when something is left" '[ "$status" -ne 0 ]'
check "deliver: two delivered, four left" '[ "$(printf "%s\n" "$out" | grep -c "^delivered: ")" = 2 ] && [ "$(count "$A/outbox")" = 4 ]'
id=$(printf '@alpha\n20261015-140000Z-@beta--hello.md\nHello.\n' | sha256sum 2>/dev/null | cut -c 1-8)
check "deliver: id from address, name and message" '[ -z "$id" ] || ls "$B/inbox" | grep -q -- "-@alpha--hello-$id.md$"'
f=$(ls "$B/inbox/"*--hello-*.md)
check "deliver: inbox file headers" '[ "$(sed -n 1,6p "$f" | cut -d: -f1 | paste -s -d " " -)" = "From To Sent Subject Id Via" ] && grep -qx "Via: local" "$f"'
check "deliver: message after a blank line" '[ "$(tail -n 2 "$f")" = "$(printf "\nHello.")" ]'
check "deliver: bytes kept exactly" '[ "$(tail -c 10 "$B/inbox/"*--????????.md)" = "no newline" ]'
check "deliver: filed with By and Sent" '[ "$(sed -n 1p "$A/sent/20261015-140000Z-@beta--hello.md")" = "By: a helper" ] && sed -n 2p "$A/sent/20261015-140000Z-@beta--hello.md" | grep -q "^Sent: .* via local$"'

# Recovery: delivered but not filed, then filed but not removed
printf 'By: a helper\n\nHello.\n' >"$A/outbox/20261015-140000Z-@beta--hello.md"
rm -f "$A/sent/20261015-140000Z-@beta--hello.md"
mv "$f" "$B/received/"
printf 'no newline' >"$A/outbox/20261015-140100Z-@beta.md"
(cd "$P/alpha" && $SH "$M" deliver >/dev/null)
check "recovery: no second copy" '[ "$(count "$B/inbox")" = 1 ] && [ "$(count "$B/received")" = 1 ]'
check "recovery: filed, outbox cleared" '[ -f "$A/sent/20261015-140000Z-@beta--hello.md" ] && [ ! -e "$A/outbox/20261015-140100Z-@beta.md" ]'

# Lock
printf 'x\n' >"$A/outbox/20261015-150000Z-@beta--locked.md"
mkdir "$A/outbox/.delivering"
check "lock: a running delivery is left alone" '(cd "$P/alpha" && $SH "$M" deliver) | grep -q "^busy:"'
touch -t 202001010000 "$A/outbox/.delivering"
check "lock: a stale lock is cleared" '(cd "$P/alpha" && $SH "$M" deliver) | grep -q "^delivered: 20261015-150000Z"'

# Hooks
hook() { printf '{"session_id":"%s","cwd":"%s"}' "$2" "$3" | $SH "$M" hook "$1" --agent "$4"; }
out=$(hook session-start s1 "$P/beta" claude)
check "session-start: lists the inbox" 'printf "%s" "$out" | grep -q "\"additionalContext\":\"You have mail: 2 messages waiting"'
check "stop: quiet when nothing is new" 'hook stop s1 "$P/beta" claude 2>/dev/null'
printf 'x\n' >"$A/outbox/20261015-160000Z-@beta--news.md"
hook stop a1 "$P/alpha" claude 2>/dev/null
check "stop: delivers, and says so once" '[ $? -eq 2 ] && hook stop a1 "$P/alpha" claude 2>/dev/null'
hook stop s1 "$P/beta" claude 2>"$T/err"
check "stop: new mail keeps Claude going once" '[ $? -eq 2 ] && grep -q "1 new message" "$T/err" && hook stop s1 "$P/beta" claude 2>/dev/null'
printf 'x\n' >"$A/outbox/20261015-170000Z-@beta--codex.md"
(cd "$P/alpha" && $SH "$M" deliver >/dev/null)
check "stop: Codex blocks once" 'hook stop c1 "$P/beta" codex | grep -q "^{\"decision\":\"block\"" && [ "$(hook stop c1 "$P/beta" codex)" = "{}" ]'

# The plugin's hooks name no agent: PLUGIN_ROOT means Codex
printf 'x\n' >"$A/outbox/20261015-180000Z-@beta--plugin.md"
(cd "$P/alpha" && $SH "$M" deliver >/dev/null)
out=$(printf '{"session_id":"p1","cwd":"%s"}' "$P/beta" | PLUGIN_ROOT=/x CLAUDE_PROJECT_DIR="$P/beta" $SH "$M" hook stop)
check "plugin hook: Codex when PLUGIN_ROOT is set" 'printf "%s" "$out" | grep -q "^{\"decision\":\"block\""'
printf '{"session_id":"p2","cwd":"%s"}' "$P/beta" | CLAUDE_PROJECT_DIR="$P/beta" $SH "$M" hook stop >/dev/null 2>&1
status=$?
check "plugin hook: Claude Code when only CLAUDE_PROJECT_DIR is set" '[ "$status" -eq 2 ]'
check "stop: no .ai/ is quiet" '[ "$(hook stop c2 "$T" codex)" = "{}" ]'

# Replies and ids
G=$P/group/Gamma.Site/.ai/mail
printf 'Re: 1a2b3c4d\n\nThanks.\n' >"$A/outbox/20261015-190000Z-@gamma-site--thanks.md"
printf 'Re: #arcana.releases:3\n\nNoted.\n' >"$A/outbox/20261015-190100Z-@gamma-site--release.md"
printf 'Re: the schema\n\nx\n' >"$A/outbox/20261015-190200Z-@gamma-site--bad.md"
out=$(cd "$P/alpha" && $SH "$M" deliver)
check "re: a line naming nothing is left in the outbox" 'printf "%s\n" "$out" | grep -q "^left in the outbox: 20261015-190200Z-@gamma-site--bad.md: its Re: line"'
id=$(printf '@alpha\n20261015-190000Z-@gamma-site--thanks.md\nThanks.\n' | sha256sum 2>/dev/null | cut -c 1-8)
check "re: not part of the id" '[ -z "$id" ] || ls "$G/inbox" | grep -q -- "--thanks-$id.md$"'
f=$(ls "$G/inbox/"*--thanks-*.md)
check "re: carried to the inbox file" '[ "$(sed -n 1,7p "$f" | cut -d: -f1 | paste -s -d " " -)" = "From To Sent Subject Id Re Via" ] && grep -qx "Re: 1a2b3c4d" "$f" && [ "$(tail -n 2 "$f")" = "$(printf "\nThanks.")" ]'
check "re: a topic's post" 'grep -qx "Re: #arcana.releases:3" "$G/inbox/"*--release-*.md'
s=$A/sent/20261015-190000Z-@gamma-site--thanks.md
check "id: the sent copy has Re, Sent and Id" '[ "$(sed -n 1,3p "$s" | cut -d: -f1 | paste -s -d " " -)" = "Re Sent Id" ] && grep -qx "Id: $(sed -n "s/^Id: //p" "$f")" "$s" && [ "$(tail -n 2 "$s")" = "$(printf "\nThanks.")" ]'

# Topics
check "topic: none yet" '$SH "$M" topic | grep -q "^no topics yet"'
check "topic: a bad name is refused" '! $SH "$M" topic "#Bad_Name" x 2>/dev/null'
check "topic: a description is needed" '! $SH "$M" topic "#news" 2>/dev/null'
check "topic: made" '[ "$($SH "$M" topic "#news" "The news, for everyone")" = "made #news" ] && [ -d "$P/.ai/topics/news" ]'
check "topic: made once" '! $SH "$M" topic news again 2>/dev/null'
check "topic: listed with no posts" '$SH "$M" topic | grep -qx "#news  *0 posts  The news, for everyone"'

# Posting (20261015-140300Z-#news--post.md waited in the outbox for #news)
N=$P/.ai/topics/news
printf 'Re: #news:1\n\nSecond.\n' >"$A/outbox/20261015-200000Z-#news--second.md"
printf 'x\n' >"$A/outbox/20261015-200100Z-#nope--x.md"
out=$(cd "$P/alpha" && $SH "$M" deliver)
check "post: numbered in order" 'printf "%s\n" "$out" | grep -qx "posted: 20261015-140300Z-#news--post.md to #news as post 1" && printf "%s\n" "$out" | grep -qx "posted: 20261015-200000Z-#news--second.md to #news as post 2"'
check "post: to a topic that doesn't exist, left" 'printf "%s\n" "$out" | grep -q "^left in the outbox: 20261015-200100Z-#nope--x.md: there.s no topic #nope"'
p=$(ls "$N" | grep "^000002-")
check "post: named and headed as an inbox file, with Post" 'printf "%s\n" "$p" | grep -qx -e "000002-[0-9]\{8\}-[0-9]\{6\}Z-@alpha--second-[0-9a-f]\{8\}\.md" && [ "$(sed -n 1,8p "$N/$p" | cut -d: -f1 | paste -s -d " " -)" = "From To Sent Subject Id Post Re Via" ] && grep -qx "Post: 2" "$N/$p"'
s=$A/sent/20261015-200000Z-#news--second.md
check "post: the sent copy has Sent, Id and Post" '[ "$(sed -n 1,4p "$s" | cut -d: -f1 | paste -s -d " " -)" = "Re Sent Id Post" ] && grep -qx "Post: 2" "$s" && [ "$(tail -n 2 "$s")" = "$(printf "\nSecond.")" ]'

# Recovery: posted but not filed keeps its number; a crashed run's lock
rm -f "$s"
printf 'Re: #news:1\n\nSecond.\n' >"$A/outbox/20261015-200000Z-#news--second.md"
check "post recovery: no second post" '(cd "$P/alpha" && $SH "$M" deliver) | grep -qx "posted: 20261015-200000Z-#news--second.md to #news as post 2" && [ "$(ls "$N" | grep -c "^0")" = 2 ] && grep -qx "Post: 2" "$s"'
mkdir "$N/.posting" && touch -t 202001010000 "$N/.posting"
printf 'Third.\n' >"$A/outbox/20261015-210000Z-#news--third.md"
check "post: a stale lock is cleared" '(cd "$P/alpha" && $SH "$M" deliver) | grep -qx "posted: 20261015-210000Z-#news--third.md to #news as post 3" && [ ! -d "$N/.posting" ]'

# Reading
out=$(cd "$P/beta" && $SH "$M" read "#news")
check "read: every post, oldest first" '[ "$(printf "%s\n" "$out" | grep -c "^==> ")" = 3 ] && printf "%s\n" "$out" | head -n 1 | grep -q "^==> 000001-"'
check "read: the place moves on" 'grep -qx "#news 3" "$B/following"'
check "read: nothing new" '(cd "$P/beta" && $SH "$M" read news) | grep -qx "no posts in #news after 3"'
check "read: after a number" '[ "$(cd "$P/beta" && $SH "$M" read news --after 1 | grep -c "^==> ")" = 2 ] && grep -qx "#news 3" "$B/following"'
check "read: no such topic" '! (cd "$P/beta" && $SH "$M" read "#nope" 2>/dev/null)'
check "topic: listed" '$SH "$M" topic | grep -qx "#news  *3 posts  The news, for everyone"'

# Following: a block list, and a flow list
G=$P/group/Gamma.Site
printf 'mail:\n  review: triage\n  follow:\n    - "#news"   # the news\n    - "#nope"\ntranscript:\n  follow: x\n' >"$G/.ai/config.yml"
out=$(hook session-start g1 "$G" claude)
check "follow: session start tells of new posts" 'printf "%s" "$out" | grep -q "3 new posts in #news"'
check "follow: and of a topic that isn't there" 'printf "%s" "$out" | grep -q "there.s no topic #nope" && ! printf "%s" "$out" | grep -q "topic x"'
check "follow: told once" 'hook stop g1 "$G" claude 2>/dev/null'
printf 'Fourth.\n' >"$A/outbox/20261015-220000Z-#news--fourth.md"
(cd "$P/alpha" && $SH "$M" deliver >/dev/null)
hook stop g1 "$G" claude 2>"$T/err"
check "follow: a new post keeps Claude going once" '[ $? -eq 2 ] && grep -q "4 new posts in #news" "$T/err" && grep -q "read .#topic." "$T/err" && hook stop g1 "$G" claude 2>/dev/null'
printf 'handle: "@beta"\nmail:\n  follow: ["#news"]  # flow\n' >"$P/beta/.ai/config.yml"
check "follow: a flow list, after the place" 'hook stop b1 "$P/beta" claude 2>&1 | grep -q "1 new post in #news"'

# Another carrier: dot-ai-mail stays out of mail
git config --file "$T/gitconfig" ai.carrier arcana
printf 'x\n' >"$A/outbox/20261015-230000Z-@beta--carried.md"
check "carrier: deliver stays out" '! (cd "$P/alpha" && $SH "$M" deliver 2>/dev/null) && [ -f "$A/outbox/20261015-230000Z-@beta--carried.md" ]'
check "carrier: the hooks are quiet" 'hook stop a9 "$P/alpha" claude 2>/dev/null && [ -f "$A/outbox/20261015-230000Z-@beta--carried.md" ]'
git config --file "$T/gitconfig" --unset ai.carrier

[ "$failed" = 0 ] && printf 'all passed\n'
exit "$failed"
