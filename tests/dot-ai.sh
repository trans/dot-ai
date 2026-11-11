#!/bin/sh
# Tests for a mail carrier (spec/mail.md): builds projects in a temporary
# directory and checks delivery, recovery, topics, receipts and the hooks.
# Run: just test. They test dot-ai's mail commands as the carrier
# (skills/dot-ai/scripts/dot-ai), or, with CARRIER=arcana, Arcana's `arcana
# mail` and `arcana hook` (the arcana on PATH, or ARCANA=/path/to/arcana),
# which must pass the same. dot-ai's own commands (send, draft, done, rm)
# are tested under either carrier: they hand delivery to it.
SH=${SH:-sh} # the shell to test under: SH="zsh --emulate sh", say
CARRIER=${CARRIER:-local}
M=$(cd "$(dirname "$0")/.." && pwd -P)/skills/dot-ai/scripts/dot-ai
T=$(mktemp -d "${TMPDIR:-/tmp}/dot-ai-test.XXXXXX") || exit 1
trap 'rm -rf "$T"' EXIT
P=$T/projects
printf '[ai]\n\tpath = %s\n[user]\n\tname = Test\n\temail = test@example.com\n[init]\n\tdefaultBranch = main\n' "$P" >"$T/gitconfig"
GIT_CONFIG_GLOBAL=$T/gitconfig XDG_RUNTIME_DIR=$T/run XDG_STATE_HOME=$T/state
export GIT_CONFIG_GLOBAL XDG_RUNTIME_DIR XDG_STATE_HOME
mkdir -p "$T/run"
unset CLAUDE_PROJECT_DIR PLUGIN_ROOT DOT_AI_BY

# The carrier's commands, and what it calls itself in Via: and Sent:
dotai() { $SH "$M" mail "$@"; } # dot-ai's own, whichever the carrier
if [ "$CARRIER" = arcana ]; then
  ARCANA=${ARCANA:-arcana}
  ARCANA_URL=http://127.0.0.1:9 # no bus: Arcana carries mail without one
  # dot-ai hands delivery to the arcana on PATH
  PATH=$(cd "$(dirname "$(command -v "$ARCANA")")" && pwd -P):$PATH
  export ARCANA_URL PATH
  carry() { "$ARCANA" mail "$@"; }
  carry_hook() { "$ARCANA" hook "$@"; }
  git config --file "$T/gitconfig" ai.carrier arcana
  VIA=arcana OTHER=local
else
  carry() { $SH "$M" mail "$@"; }
  carry_hook() { $SH "$M" hook "$@"; }
  VIA=local OTHER=arcana
fi
# A stand-in for Codex's codex, so no test reaches a real Codex: it notes
# how it was called
mkdir -p "$T/fake"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/codex.calls"\n' "$T" >"$T/fake/codex"
chmod +x "$T/fake/codex"
PATH=$T/fake:$PATH
export PATH

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
project group/Gamma.Site 'description: a config without a handle'
project bare '' # mail folders, but no config: no agent set up
project twin1 'handle: twin'
project twin2 "handle: 'twin'"
project .hidden/eps 'handle: eps'
mkdir -p "$P/delta/.ai" && printf 'handle: delta\n' >"$P/delta/.ai/config.yml"
mkdir -p "$P/.ai" # the topic home: the first ai.path directory
ln -s alpha "$P/link"
A=$P/alpha/.ai/mail B=$P/beta/.ai/mail

# Finding
check "find: quoted handle" '[ "$(carry find beta)" = "$P/beta" ]'
check "find: folded directory name" '[ "$(carry find gamma-site)" = "$P/group/Gamma.Site" ]'
check "find: two projects, one address" '! carry find twin 2>/dev/null'
check "find: hidden directories and links skipped" '! carry find eps 2>/dev/null && [ "$(carry find | grep -c "/alpha$")" = 1 ]'
check "find: marks a project without a config" 'carry find | grep -q "^@bare  *$P/bare (no .ai/config.yml: no mail is delivered to it)$" && ! carry find | grep -q "/alpha (no"'

# No delivery into a project without a config
printf 'x\n' >"$A/outbox/20261015-135900Z-@bare--unread.md"
out=$(cd "$P/alpha" && carry deliver)
check "deliver: none into a project without a config" 'printf "%s\n" "$out" | grep -qxF "left in the outbox: 20261015-135900Z-@bare--unread.md: @bare ($P/bare) has no .ai/config.yml, so no agent is set up there" && [ "$(count "$P/bare/.ai/mail/inbox")" = 0 ]'
rm -f "$A/outbox/20261015-135900Z-@bare--unread.md"

# Delivering
printf 'By: a helper\n\nHello.\n' >"$A/outbox/20261015-140000Z-@beta--hello.md"
printf 'no newline' >"$A/outbox/20261015-140100Z-@beta.md"
printf 'x\n' >"$A/outbox/20261015-140200Z-@twin--dup.md"
printf 'x\n' >"$A/outbox/20261015-140300Z-#news--post.md"
printf 'x\n' >"$A/outbox/20261015-140400Z-@delta--nomail.md"
printf 'x\n' >"$A/outbox/old-name.md"
out=$(cd "$P/alpha" && carry deliver)
status=$?
check "deliver: fails when something is left" '[ "$status" -ne 0 ]'
check "deliver: two delivered, four left" '[ "$(printf "%s\n" "$out" | grep -c "^delivered: ")" = 2 ] && [ "$(count "$A/outbox")" = 4 ]'
id=$(printf '@alpha\n20261015-140000Z-@beta--hello.md\nHello.\n' | sha256sum 2>/dev/null | cut -c 1-8)
check "deliver: id from address, name and message" '[ -z "$id" ] || ls "$B/inbox" | grep -q -- "-@alpha--hello-$id.md$"'
f=$(ls "$B/inbox/"*--hello-*.md)
check "deliver: inbox file headers" '[ "$(sed -n 1,6p "$f" | cut -d: -f1 | paste -s -d " " -)" = "From To Sent Subject Id Via" ] && grep -qx "Via: $VIA" "$f"'
check "deliver: message after a blank line" '[ "$(tail -n 2 "$f")" = "$(printf "\nHello.")" ]'
check "deliver: bytes kept exactly" '[ "$(tail -c 10 "$B/inbox/"*--????????.md)" = "no newline" ]'
check "deliver: filed with By and Sent" '[ "$(sed -n 1p "$A/sent/20261015-140000Z-@beta--hello.md")" = "By: a helper" ] && sed -n 2p "$A/sent/20261015-140000Z-@beta--hello.md" | grep -q "^Sent: .* via $VIA$"'

# Recovery: delivered but not filed, then filed but not removed
printf 'By: a helper\n\nHello.\n' >"$A/outbox/20261015-140000Z-@beta--hello.md"
rm -f "$A/sent/20261015-140000Z-@beta--hello.md"
mv "$f" "$B/received/"
printf 'no newline' >"$A/outbox/20261015-140100Z-@beta.md"
(cd "$P/alpha" && carry deliver >/dev/null)
check "recovery: no second copy" '[ "$(count "$B/inbox")" = 1 ] && [ "$(count "$B/received")" = 1 ]'
check "recovery: filed, outbox cleared" '[ -f "$A/sent/20261015-140000Z-@beta--hello.md" ] && [ ! -e "$A/outbox/20261015-140100Z-@beta.md" ]'

# Lock
printf 'x\n' >"$A/outbox/20261015-150000Z-@beta--locked.md"
mkdir "$A/outbox/.delivering"
check "lock: a running delivery is left alone" '(cd "$P/alpha" && carry deliver) | grep -q "^busy:"'
touch -t 202001010000 "$A/outbox/.delivering"
check "lock: a stale lock is cleared" '(cd "$P/alpha" && carry deliver) | grep -q "^delivered: 20261015-150000Z"'

# An inbox it can't write to (as from a sandbox): left, saying to leave it
project omega 'handle: omega'
chmod 555 "$P/omega/.ai/mail/inbox"
printf 'x\n' >"$A/outbox/20261015-155000Z-@omega--shut.md"
check "deliver: can't write, left for the hooks" '(cd "$P/alpha" && carry deliver) | grep -q "^left in the outbox: 20261015-155000Z-@omega--shut.md: couldn.t write to .*leave it" && [ -f "$A/outbox/20261015-155000Z-@omega--shut.md" ]'
chmod 755 "$P/omega/.ai/mail/inbox"
(cd "$P/alpha" && carry deliver >/dev/null)

# Hooks
hook() { printf '{"session_id":"%s","cwd":"%s"}' "$2" "$3" | carry_hook "$1" --agent "$4"; }
out=$(hook session-start s1 "$P/beta" claude)
check "session-start: lists the inbox" 'printf "%s" "$out" | grep -q "\"additionalContext\":\"You have mail: 2 messages waiting"'
[ "$CARRIER" = arcana ] || check "session-start: says how to file" 'printf "%s" "$out" | grep -q "mail done NAME"'
check "stop: quiet when nothing is new" 'hook stop s1 "$P/beta" claude 2>/dev/null'
printf 'x\n' >"$A/outbox/20261015-160000Z-@beta--news.md"
hook stop a1 "$P/alpha" claude 2>/dev/null
check "stop: delivers, and says so once" '[ $? -eq 2 ] && hook stop a1 "$P/alpha" claude 2>/dev/null'
hook stop s1 "$P/beta" claude 2>"$T/err"
check "stop: new mail keeps Claude going once" '[ $? -eq 2 ] && grep -q "1 new message" "$T/err" && hook stop s1 "$P/beta" claude 2>/dev/null'
printf 'x\n' >"$A/outbox/20261015-170000Z-@beta--codex.md"
(cd "$P/alpha" && carry deliver >/dev/null)
check "stop: Codex blocks once" 'hook stop c1 "$P/beta" codex | grep -q "^{\"decision\":\"block\"" && [ "$(hook stop c1 "$P/beta" codex)" = "{}" ]'

# The plugin's hooks name no agent: PLUGIN_ROOT means Codex
printf 'x\n' >"$A/outbox/20261015-180000Z-@beta--plugin.md"
(cd "$P/alpha" && carry deliver >/dev/null)
out=$(printf '{"session_id":"p1","cwd":"%s"}' "$P/beta" | (export PLUGIN_ROOT=/x CLAUDE_PROJECT_DIR="$P/beta"; carry_hook stop))
check "plugin hook: Codex when PLUGIN_ROOT is set" 'printf "%s" "$out" | grep -q "^{\"decision\":\"block\""'
printf '{"session_id":"p2","cwd":"%s"}' "$P/beta" | (export CLAUDE_PROJECT_DIR="$P/beta"; carry_hook stop) >/dev/null 2>&1
status=$?
check "plugin hook: Claude Code when only CLAUDE_PROJECT_DIR is set" '[ "$status" -eq 2 ]'
check "stop: no .ai/ is quiet" '[ "$(hook stop c2 "$T" codex)" = "{}" ]'

# Replies and ids
G=$P/group/Gamma.Site/.ai/mail
printf 'Re: 1a2b3c4d\n\nThanks.\n' >"$A/outbox/20261015-190000Z-@gamma-site--thanks.md"
printf 'Re: #arcana.releases:3\n\nNoted.\n' >"$A/outbox/20261015-190100Z-@gamma-site--release.md"
printf 'Re: the schema\n\nx\n' >"$A/outbox/20261015-190200Z-@gamma-site--bad.md"
out=$(cd "$P/alpha" && carry deliver)
check "re: a line naming nothing is left in the outbox" 'printf "%s\n" "$out" | grep -q "^left in the outbox: 20261015-190200Z-@gamma-site--bad.md: its Re: line"'
id=$(printf '@alpha\n20261015-190000Z-@gamma-site--thanks.md\nThanks.\n' | sha256sum 2>/dev/null | cut -c 1-8)
check "re: not part of the id" '[ -z "$id" ] || ls "$G/inbox" | grep -q -- "--thanks-$id.md$"'
f=$(ls "$G/inbox/"*--thanks-*.md)
check "re: carried to the inbox file" '[ "$(sed -n 1,7p "$f" | cut -d: -f1 | paste -s -d " " -)" = "From To Sent Subject Id Re Via" ] && grep -qx "Re: 1a2b3c4d" "$f" && [ "$(tail -n 2 "$f")" = "$(printf "\nThanks.")" ]'
check "re: a topic's post" 'grep -qx "Re: #arcana.releases:3" "$G/inbox/"*--release-*.md'
s=$A/sent/20261015-190000Z-@gamma-site--thanks.md
check "id: the sent copy has Re, Sent and Id" '[ "$(sed -n 1,3p "$s" | cut -d: -f1 | paste -s -d " " -)" = "Re Sent Id" ] && grep -qx "Id: $(sed -n "s/^Id: //p" "$f")" "$s" && [ "$(tail -n 2 "$s")" = "$(printf "\nThanks.")" ]'

# Topics
check "topic: none yet" 'carry topic | grep -q "^no topics yet"'
check "topic: a bad name is refused" '! carry topic "#Bad_Name" x 2>/dev/null'
check "topic: a description is needed" '! carry topic "#news" 2>/dev/null'
check "topic: made" '[ "$(carry topic "#news" "The news, for everyone")" = "made #news" ] && [ -d "$P/.ai/topics/news" ]'
check "topic: made once" '! carry topic news again 2>/dev/null'
check "topic: listed with no posts" 'carry topic | grep -qx "#news  *0 posts  The news, for everyone"'

# Posting (20261015-140300Z-#news--post.md waited in the outbox for #news)
N=$P/.ai/topics/news
printf 'Re: #news:1\n\nSecond.\n' >"$A/outbox/20261015-200000Z-#news--second.md"
printf 'x\n' >"$A/outbox/20261015-200100Z-#nope--x.md"
out=$(cd "$P/alpha" && carry deliver)
check "post: numbered in order" 'printf "%s\n" "$out" | grep -qx "posted: 20261015-140300Z-#news--post.md to #news as post 1" && printf "%s\n" "$out" | grep -qx "posted: 20261015-200000Z-#news--second.md to #news as post 2"'
check "post: to a topic that doesn't exist, left" 'printf "%s\n" "$out" | grep -q "^left in the outbox: 20261015-200100Z-#nope--x.md: there.s no topic #nope"'
p=$(ls "$N" | grep "^000002-")
check "post: named and headed as an inbox file, with Post" 'printf "%s\n" "$p" | grep -qx -e "000002-[0-9]\{8\}-[0-9]\{6\}Z-@alpha--second-[0-9a-f]\{8\}\.md" && [ "$(sed -n 1,8p "$N/$p" | cut -d: -f1 | paste -s -d " " -)" = "From To Sent Subject Id Post Re Via" ] && grep -qx "Post: 2" "$N/$p"'
s=$A/sent/20261015-200000Z-#news--second.md
check "post: the sent copy has Sent, Id and Post" '[ "$(sed -n 1,4p "$s" | cut -d: -f1 | paste -s -d " " -)" = "Re Sent Id Post" ] && grep -qx "Post: 2" "$s" && [ "$(tail -n 2 "$s")" = "$(printf "\nSecond.")" ]'

# Recovery: posted but not filed keeps its number; a crashed run's lock
rm -f "$s"
printf 'Re: #news:1\n\nSecond.\n' >"$A/outbox/20261015-200000Z-#news--second.md"
check "post recovery: no second post" '(cd "$P/alpha" && carry deliver) | grep -qx "posted: 20261015-200000Z-#news--second.md to #news as post 2" && [ "$(ls "$N" | grep -c "^0")" = 2 ] && grep -qx "Post: 2" "$s"'
mkdir "$N/.posting" && touch -t 202001010000 "$N/.posting"
printf 'Third.\n' >"$A/outbox/20261015-210000Z-#news--third.md"
check "post: a stale lock is cleared" '(cd "$P/alpha" && carry deliver) | grep -qx "posted: 20261015-210000Z-#news--third.md to #news as post 3" && [ ! -d "$N/.posting" ]'

# Reading
out=$(cd "$P/beta" && carry read "#news")
check "read: every post, oldest first" '[ "$(printf "%s\n" "$out" | grep -c "^==> ")" = 3 ] && printf "%s\n" "$out" | head -n 1 | grep -q "^==> 000001-"'
check "read: the place moves on" 'grep -qx "#news 3" "$B/following"'
check "read: nothing new" '(cd "$P/beta" && carry read news) | grep -qx "no posts in #news after 3"'
check "read: after a number" '[ "$(cd "$P/beta" && carry read news --after 1 | grep -c "^==> ")" = 2 ] && grep -qx "#news 3" "$B/following"'
check "read: no such topic" '! (cd "$P/beta" && carry read "#nope" 2>/dev/null)'
check "topic: listed" 'carry topic | grep -qx "#news  *3 posts  The news, for everyone"'

# Following: a block list, and a flow list
G=$P/group/Gamma.Site
printf 'mail:\n  review: triage\n  follow:\n    - "#news"   # the news\n    - "#nope"\ntranscript:\n  follow: x\n' >"$G/.ai/config.yml"
out=$(hook session-start g1 "$G" claude)
check "follow: session start tells of new posts" 'printf "%s" "$out" | grep -q "3 new posts in #news"'
check "follow: and of a topic that isn't there" 'printf "%s" "$out" | grep -q "there.s no topic #nope" && ! printf "%s" "$out" | grep -q "topic x"'
check "follow: told once" 'hook stop g1 "$G" claude 2>/dev/null'
printf 'Fourth.\n' >"$A/outbox/20261015-220000Z-#news--fourth.md"
(cd "$P/alpha" && carry deliver >/dev/null)
hook stop g1 "$G" claude 2>"$T/err"
check "follow: a new post keeps Claude going once" '[ $? -eq 2 ] && grep -q "4 new posts in #news" "$T/err" && grep -q "read .#topic." "$T/err" && hook stop g1 "$G" claude 2>/dev/null'
printf 'handle: "@beta"\nmail:\n  follow: ["#news"]  # flow\n' >"$P/beta/.ai/config.yml"
check "follow: a flow list, after the place" 'hook stop b1 "$P/beta" claude 2>&1 | grep -q "1 new post in #news"'

# Sending with dot-ai: it names the file, writes it and has it delivered
out=$(cd "$P/alpha" && printf 'Plans for the schema.\n' | dotai send @beta "Schema plans!")
n=$(ls "$A/sent" | grep -- "-@beta--schema-plans.md$")
check "send: named from the topic, delivered" '[ -n "$n" ] && printf "%s\n" "$out" | grep -qx "delivered: $n to @beta"'
check "send: filed with the message as given" '[ "$(tail -n 2 "$A/sent/$n")" = "$(printf "\nPlans for the schema.")" ] && ! grep -q "^Re: " "$A/sent/$n"'
out=$(cd "$P/alpha" && printf 'Thanks.' | dotai send beta thanks --re 1a2b3c4d)
n=$(ls "$A/sent" | grep -- "-@beta--thanks.md$")
check "send: --re heads it, a newline ends it" '[ "$(sed -n 1p "$A/sent/$n")" = "Re: 1a2b3c4d" ] && [ "$(tail -n 1 "$A/sent/$n")" = "Thanks." ] && f=$(ls "$B/inbox/"*--thanks-*.md) && grep -qx "Re: 1a2b3c4d" "$f"'
out=$(cd "$P/alpha" && printf 'Ready.\n' | dotai send @beta "Deploy landing-v0.8.2… (e.g. 1.2.3.4_x)")
check "send: a . kept between digits, and only there" 'printf "%s\n" "$out" | grep -q -- "-@beta--deploy-landing-v0.8.2-e-g-1.2.3.4-x.md to @beta$"'
check "send: a post" '(cd "$P/alpha" && printf "Fifth.\n" | dotai send "#news" "the fifth") | grep -q "^posted: .*-#news--the-fifth.md to #news as post 5$"'
before=$(count "$A/outbox")
check "send: refuses a bad address, a bad --re, an empty message" '! (cd "$P/alpha" && printf "x\n" | dotai send "Beta Team" x 2>/dev/null) && ! (cd "$P/alpha" && printf "x\n" | dotai send @beta x --re "the schema" 2>/dev/null) && ! (cd "$P/alpha" && printf "  \n" | dotai send @beta x 2>/dev/null) && [ "$(count "$A/outbox")" = "$before" ]'
inbox=$(count "$B/inbox")
out=$(cd "$P/alpha" && printf 'We ship Friday.\n' | dotai draft @beta friday --why "promises a date")
d=$(ls "$A/drafts")
check "draft: waits in drafts, saying how to send it" 'printf "%s\n" "$out" | grep -q "^drafted: $d, in .ai/mail/drafts/: tell the user; once they approve, dot-ai mail send $d$" && [ "$(sed -n 1p "$A/drafts/$d")" = "Held: promises a date" ] && [ "$(count "$B/inbox")" = "$inbox" ]'
check "send: --why is for a draft" '! (cd "$P/alpha" && printf "x\n" | dotai send @beta x --why y 2>/dev/null)'
out=$(cd "$P/alpha" && dotai send "$d")
check "send NAME: the draft, without its Held line" 'printf "%s\n" "$out" | grep -qx "delivered: $d to @beta" && [ "$(count "$A/drafts")" = 0 ] && ! grep -q "^Held: " "$A/sent/$d" && [ "$(tail -n 2 "$A/sent/$d")" = "$(printf "\nWe ship Friday.")" ]'
(cd "$P/alpha" && printf 'From a helper.\n' | dotai draft @beta helped --by "a helper" --why "a promise" >/dev/null)
d=$(ls "$A/drafts")
(cd "$P/alpha" && dotai send "$A/drafts/$d" >/dev/null)
check "send NAME: keeps By, by path" '[ "$(sed -n 1p "$A/sent/$d")" = "By: a helper" ] && ! grep -q "^Held: " "$A/sent/$d"'
check "send NAME: no such draft" '! (cd "$P/alpha" && dotai send nosuch.md 2>/dev/null)'
(cd "$P/alpha" && printf 'Never mind.\n' | dotai draft @beta nevermind --by "a helper" >/dev/null)
check "rm: a draft" '(cd "$P/alpha" && dotai rm "$(ls "$A/drafts")") | grep -q "never sent" && [ "$(count "$A/drafts")" = 0 ]'

# Dealing with the inbox
f=$(ls "$B/inbox" | grep -- "--friday-") id=${f%.md} id=${id##*-}
check "done: by id, filed under received" '(cd "$P/beta" && dotai done "$id") | grep -qx "filed: .ai/mail/received/$f: commit it with the notes it went into" && [ -f "$B/received/$f" ] && [ ! -e "$B/inbox/$f" ]'
f=$(ls "$B/inbox" | grep -- "--helped-")
check "done: by path, from anywhere" 'dotai done "$B/inbox/$f" >/dev/null && [ -f "$B/received/$f" ]'
f=$(ls "$B/inbox" | grep -- "--thanks-" | head -n 1)
check "rm: out of the inbox, not filed" '(cd "$P/beta" && dotai rm "$f") | grep -q "^removed: $f, not filed" && [ ! -e "$B/inbox/$f" ] && [ ! -e "$B/received/$f" ]'
printf 'From: #news\n\nA notice.\n' >"$B/inbox/20261015-120000Z-#news--notice-12345678.md"
check "done: a topic's notice is removed, not filed" '(cd "$P/beta" && dotai done 12345678) | grep -q "a notice from a topic" && [ ! -e "$B/received/20261015-120000Z-#news--notice-12345678.md" ]'
check "done: nothing by that name" '! (cd "$P/beta" && dotai done nosuch.md 2>/dev/null)'
check "dot-ai-mail: the old name still works" '[ "$($SH "$(dirname "$M")/dot-ai-mail" find beta)" = "$P/beta" ] && $SH "$(dirname "$M")/dot-ai-mail" version | grep -q "^dot-ai "'

# Receipts
project rho 'handle: rho'
project sigma 'handle: sigma'
R=$P/rho/.ai/mail S=$P/sigma/.ai/mail
printf 'One.\n' >"$R/outbox/20261016-100000Z-@sigma--one.md"
printf 'Two.\n' >"$R/outbox/20261016-100100Z-@sigma--two.md"
printf 'Three.\n' >"$R/outbox/20261016-100200Z-@sigma--three.md"
printf 'Post.\n' >"$R/outbox/20261016-100300Z-#news--rho.md"
(cd "$P/rho" && carry deliver >/dev/null)
check "receipts: one waits for each message, none for a post" '[ "$(wc -l <"$R/outbox/.receipts" | tr -d " ")" = 3 ]'
check "prompt: quiet while nothing is read" '[ -z "$(hook prompt r1 "$P/rho" claude)" ] && [ "$(hook prompt r1 "$P/rho" codex)" = "{}" ]'
mv "$S/inbox/"*--one-*.md "$S/received/"
rm "$S/inbox/"*--two-*.md
printf 'deadbeef\t@ghost\t%s\t20261016-100500Z-@ghost--boo.md\n' "$T/nowhere" >>"$R/outbox/.receipts"
printf 'cafef00d\t@far\tarcana\t20261016-100600Z-@far--away.md\n' >>"$R/outbox/.receipts"
mkdir "$R/outbox/.delivering"
check "prompt: quiet while a delivery runs" '[ -z "$(hook prompt r1 "$P/rho" claude)" ] && [ "$(wc -l <"$R/outbox/.receipts" | tr -d " ")" = 5 ]'
rmdir "$R/outbox/.delivering"
printf 'Four.\n' >"$R/outbox/20261016-100400Z-@sigma--four.md"
out=$(hook prompt r1 "$P/rho" claude)
check "prompt: tells of a message read" 'printf "%s" "$out" | grep -q "^{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":\"Receipts for mail this project sent" && printf "%s" "$out" | grep -q "@sigma read 20261016-100000Z-@sigma--one.md"'
check "prompt: of one taken out unfiled, and one whose project is gone" 'printf "%s" "$out" | grep -q "@sigma took 20261016-100100Z-@sigma--two.md out of its inbox" && printf "%s" "$out" | grep -q "@ghost: no telling whether it read"'
check "prompt: each told once, and nothing delivered" '[ -z "$(hook prompt r1 "$P/rho" claude)" ] && [ "$(wc -l <"$R/outbox/.receipts" | tr -d " ")" = 2 ] && [ -f "$R/outbox/20261016-100400Z-@sigma--four.md" ]'
check "receipts: another carrier's line is left" 'grep -q "^cafef00d$(printf "\t")@far$(printf "\t")arcana" "$R/outbox/.receipts" && ! printf "%s" "$out" | grep -q "@far"'
sed -i.bak '/^cafef00d/d' "$R/outbox/.receipts" && rm -f "$R/outbox/.receipts.bak"
mv "$S/inbox/"*--three-*.md "$S/received/"
rm "$R/outbox/20261016-100400Z-@sigma--four.md"
check "stop: a receipt alone doesn't keep Claude going" 'hook stop r2 "$P/rho" claude 2>/dev/null && grep -q -- "--three.md$" "$R/outbox/.receipts"'
printf 'Four.\n' >"$R/outbox/20261016-100400Z-@sigma--four.md"
hook stop r2 "$P/rho" claude 2>"$T/err"
check "stop: told with something else to say" '[ $? -eq 2 ] && grep -q "sent 1 message" "$T/err" && grep -q "@sigma read 20261016-100200Z-@sigma--three.md" "$T/err" && ! grep -q -- "--three.md$" "$R/outbox/.receipts"'
mv "$S/inbox/"*--four-*.md "$S/received/"
check "session-start: tells of receipts" 'hook session-start r3 "$P/rho" claude | grep -q "@sigma read 20261016-100400Z-@sigma--four.md" && [ ! -e "$R/outbox/.receipts" ]'
if [ "$CARRIER" = local ]; then
  printf 'Five.\n' >"$R/outbox/20261016-100500Z-@sigma--five.md"
  (cd "$P/rho" && carry deliver >/dev/null)
  check "receipts: mail receipts, none yet" '[ -z "$(cd "$P/rho" && carry receipts)" ]'
  mv "$S/inbox/"*--five-*.md "$S/received/"
  check "receipts: mail receipts, a line each, then none" '[ "$(cd "$P/rho" && carry receipts)" = "@sigma read 20261016-100500Z-@sigma--five.md" ] && [ -z "$(cd "$P/rho" && carry receipts)" ]'
fi

# Setting up: init and install (dot-ai's own, under either carrier)
top() { $SH "$M" "$@"; }
mkdir -p "$P/newproj" && git -C "$P/newproj" init -q
out=$(cd "$P/newproj" && top init)
check "init: .ai/ on its own ai branch, committed" '[ "$(git -C "$P/newproj/.ai" rev-parse --abbrev-ref HEAD)" = ai ] && [ -z "$(git -C "$P/newproj/.ai" status --porcelain)" ] && git -C "$P/newproj/.ai" ls-files | grep -qx mail/inbox/.gitkeep'
check "init: the handle from the checkout's name, found by mail" 'grep -q "^handle: newproj " "$P/newproj/.ai/config.yml" && [ "$(carry find newproj)" = "$P/newproj" ]'
check "init: the checkout ignores .ai/, committed alone" 'grep -qx "/.ai/" "$P/newproj/.gitignore" && [ -z "$(git -C "$P/newproj" status --porcelain)" ] && [ "$(git -C "$P/newproj" rev-list --count HEAD)" = 1 ]'
check "init: Intake and Outtake, never committed" '[ "$(cat "$P/newproj/Intake/.gitignore")" = "*" ] && [ -f "$P/newproj/Outtake/.gitignore" ]'
check "init: a ✓ for each thing it did" '[ "$(printf "%s\n" "$out" | grep -c "^✓ ")" = 6 ] && [ "$(printf "%s\n" "$out" | grep -c -v "^✓ \|^next: ")" = 0 ]'
check "init: once" '! (cd "$P/newproj" && top init 2>/dev/null)'
mkdir -p "$P/another" && git -C "$P/another" init -q
check "init: a handle that's taken is refused, touching nothing" '! (cd "$P/another" && top init beta 2>/dev/null) && [ ! -e "$P/another/.ai" ] && [ ! -e "$P/another/.gitignore" ]'
mkdir -p "$T/oldgit" "$P/oldproj" && git -C "$P/oldproj" init -q
printf '#!/bin/sh\ncase " $* " in *" worktree add "*--orphan*) exit 129 ;; esac\nexec %s "$@"\n' "$(command -v git)" >"$T/oldgit/git"
chmod +x "$T/oldgit/git"
check "init: git before 2.42" '(cd "$P/oldproj" && PATH=$T/oldgit:$PATH top init >/dev/null) && [ -z "$(git -C "$P/oldproj/.ai" status --porcelain)" ] && [ "$(git -C "$P/oldproj/.ai" ls-files | grep -c -v "^mail/\|^memory/\|^config.yml$\|^.gitignore$")" = 0 ] && [ "$(git -C "$P/oldproj/.ai" rev-list --count ai)" = 1 ]'
check "init: not in a git checkout" '! (cd "$T" && top init x 2>/dev/null)'
mkdir -p "$T/out" && git -C "$T/out" init -q
check "init: outside ai.path, says so" '(cd "$T/out" && top init outsider) | grep -q "outside ai.path"'
git clone -q "$P/newproj" "$T/clone"
check "init: a clone checks the ai branch out" '(cd "$T/clone" && top init) | grep -q "checked out the ai branch .*: this project is @newproj" && [ -f "$T/clone/.ai/config.yml" ]'
top install "$T/bin2" >/dev/null
check "install: this copy, while no plugin has one" '[ -x "$T/bin2/dot-ai" ] && [ "$(CLAUDE_CONFIG_DIR=$T/claude CODEX_HOME=$T/codex "$T/bin2/dot-ai" version)" = "$(top version)" ]'
for v in 0.9.0 0.10.0; do
  mkdir -p "$T/claude/plugins/cache/dot-ai/dot-ai/$v/skills/dot-ai/scripts"
  printf 'echo copy %s\n' "$v" >"$T/claude/plugins/cache/dot-ai/dot-ai/$v/skills/dot-ai/scripts/dot-ai"
done
mkdir -p "$T/codex/plugins/cache/dot-ai/dot-ai/0.9.5/skills/dot-ai/scripts"
printf 'echo copy 0.9.5\n' >"$T/codex/plugins/cache/dot-ai/dot-ai/0.9.5/skills/dot-ai/scripts/dot-ai"
check "install: the newest plugin copy, from either tool" '[ "$(CLAUDE_CONFIG_DIR=$T/claude CODEX_HOME=$T/codex "$T/bin2/dot-ai")" = "copy 0.10.0" ]'
check "install: again, over its own" 'top install "$T/bin2" >/dev/null'
mkdir -p "$T/bin3" && printf '#!/bin/sh\n' >"$T/bin3/dot-ai"
check "install: leaves a dot-ai it didn't write" '! top install "$T/bin3" 2>/dev/null && [ "$(cat "$T/bin3/dot-ai")" = "#!/bin/sh" ]'

# The mail channel: an MCP server for Claude Code's channels (dot-ai's own)
V=$($SH "$M" version | cut -d ' ' -f 2)
out=$(printf '%s\n' \
  '{"jsonrpc":"2.0","id":"p-1","method":"server/discover","params":{"_meta":{"id":"nested","method":"x"}}}' \
  '{"method":"initialize","params":{"protocolVersion":"2025-11-25","clientInfo":{"name":"t \"q\" {x}","id":9}},"jsonrpc":"2.0","id":0}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{ "jsonrpc" : "2.0" , "id" : 2 , "method" : "ping" }' \
  '{"jsonrpc":"2.0","id":3,"result":{}}' | $SH "$M" channel)
init='{"jsonrpc":"2.0","id":0,"result":{"protocolVersion":"2025-11-25","capabilities":{"experimental":{"claude/channel":{}}},"serverInfo":{"name":"dot-ai","version":"'$V'"}}}'
check "channel: initialize, with the channel's capability" 'printf "%s\n" "$out" | grep -qxF "$init"'
check "channel: the top-level id, not a nested one" 'printf "%s\n" "$out" | grep -qxF "{\"jsonrpc\":\"2.0\",\"id\":\"p-1\",\"error\":{\"code\":-32601,\"message\":\"no such method\"}}"'
check "channel: ping; no answer to a notification or a response" 'printf "%s\n" "$out" | grep -qxF "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{}}" && [ "$(printf "%s\n" "$out" | wc -l | tr -d " ")" = 3 ]'

if [ "$CARRIER" = local ]; then
  R=$T/run/dot-ai SD=$T/state/dot-ai/sessions
  rm -f "$SD"/*.session # the sessions of the tests above
  send() { (cd "$P/beta" && printf 'Hi.\n' | dotai send @alpha "$1") >/dev/null; }
  pushes() { grep -c '"method":"notifications/claude/channel"' "$T/chan.out"; }
  within() { i=0; while [ $i -lt 8 ]; do eval "$1" && return 0; sleep 1; i=$((i + 1)); done; return 1; }
  state() { sed -n 's/^state=//p' "$SD/$1.session" 2>/dev/null; }
  field() { sed -n "s/^$2=//p" "$SD/$1.session" 2>/dev/null; }

  # The hooks keep each session's record
  hook session-start s-chan "$P/alpha" claude >/dev/null 2>&1
  check "record: a session's start makes it, idle" '[ "$(state s-chan)" = idle ] && [ "$(field s-chan root)" = "$(cd "$P/alpha" && pwd -P)" ] && [ "$(field s-chan agent)" = claude ] && [ "$(field s-chan id)" = s-chan ]'
  check "record: in the person's state directory, private to them" '[ "$(ls -ld "$SD" | cut -c1-10)" = drwx------ ]'
  check "record: its runner, without DOT_AI_BY or ai.runner, dot-ai" '[ "$(field s-chan by)" = dot-ai ]'
  hook prompt s-chan "$P/alpha" claude >/dev/null 2>&1
  check "record: a prompt makes it busy" '[ "$(state s-chan)" = busy ]'
  hook stop s-chan "$P/alpha" claude >/dev/null 2>&1
  check "record: a Stop that lets the turn end makes it idle" '[ "$(state s-chan)" = idle ]'
  printf '{"session_id":"s-cmp","cwd":"%s","source":"compact"}' "$P/alpha" | carry_hook session-start --agent claude >/dev/null 2>&1
  check "record: a start from compacting, maybe mid-turn, is busy" '[ "$(state s-cmp)" = busy ]'
  hook session-end s-cmp "$P/alpha" claude >/dev/null 2>&1
  check "record: a session's end marks it ended" '[ "$(state s-cmp)" = ended ]'
  (DOT_AI_BY=aix && export DOT_AI_BY && hook session-start s-by "$P/alpha" claude >/dev/null 2>&1)
  check "record: its runner, DOT_AI_BY" '[ "$(field s-by by)" = aix ]'
  hook prompt s-by "$P/alpha" claude >/dev/null 2>&1
  check "record: its runner, kept from its start" '[ "$(field s-by by)" = aix ] && [ "$(state s-by)" = busy ]'
  git config --file "$T/gitconfig" --add ai.runner tom
  git config --file "$T/gitconfig" --add ai.runner aix
  (DOT_AI_BY='../bin/x' && export DOT_AI_BY && hook session-start s-run "$P/alpha" codex >/dev/null 2>&1)
  check "record: its runner, else ai.runner's first, never a path" '[ "$(field s-run by)" = tom ] && [ -z "$(field s-run pid)" ]'
  git config --file "$T/gitconfig" --unset-all ai.runner
  # Claude Code's process, as the record's pid: a shell named claude
  cp "$(command -v sh)" "$T/fake/claude"
  printf '{"session_id":"s-pid","cwd":"%s"}' "$P/alpha" >"$T/pid.json"
  "$T/fake/claude" -c 'printf "%s\n" "$$" >"$1/pid"; $2 "$3" hook session-start --agent claude <"$1/pid.json" >/dev/null 2>&1; :' claude "$T" "$SH" "$M"
  check "record: Claude Code's process, as pid" '[ -n "$(field s-pid pid)" ] && [ "$(field s-pid pid)" = "$(cat "$T/pid")" ]'
  rm -f "$SD/s-by.session" "$SD/s-run.session" "$SD/s-pid.session"

  # A session of Claude Code's started with this plugin's channel, which
  # runs as its child, as Claude Code runs it
  mkfifo "$T/chan.in"
  CLAUDE_CODE_SESSION_ID=s-chan CLAUDE_PROJECT_DIR=$P/alpha \
    sh -c "$SH \"$M\" channel; :" claude --dangerously-load-development-channels plugin:dot-ai@dot-ai <"$T/chan.in" >"$T/chan.out" &
  chan=$!
  exec 3>"$T/chan.in"
  printf '%s\n' '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{}}' '{"jsonrpc":"2.0","method":"notifications/initialized"}' >&3
  check "channel: waits on its pipe" 'within "[ -p \"$R/s-chan.pipe\" ] && [ -s \"$R/s-chan.chan\" ]"'
  send "channel one"
  check "channel: mail arriving while idle, pushed once" 'within "[ \"\$(pushes)\" = 1 ]" && sleep 2 && [ "$(pushes)" = 1 ] && grep -qxF "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/claude/channel\",\"params\":{\"content\":\"You have mail in .ai/mail/inbox/.\"}}" "$T/chan.out"'
  check "channel: the push makes the session busy" '[ "$(state s-chan)" = busy ]'
  check "channel: mail the agent left in the inbox, the Stop hook still tells" 'hook stop s-chan "$P/alpha" claude 2>&1 | grep -q -- "--channel-one-"'
  hook stop s-chan "$P/alpha" claude >/dev/null 2>&1
  hook prompt s-chan "$P/alpha" claude >/dev/null 2>&1
  send "channel two"
  sleep 2
  check "channel: nothing while busy" '[ "$(pushes)" = 1 ]'
  hook stop s-chan "$P/alpha" claude >/dev/null 2>&1 # tells of it
  hook stop s-chan "$P/alpha" claude >/dev/null 2>&1
  send "channel three"
  check "channel: pushed once idle again" 'within "[ \"\$(pushes)\" = 2 ]"'
  hook stop s-chan "$P/alpha" claude >/dev/null 2>&1
  hook stop s-chan "$P/alpha" claude >/dev/null 2>&1

  # A Codex session: delivery queues the notice into it with codex queue
  : >"$T/codex.calls"
  hook session-start c-one "$P/alpha" codex >/dev/null 2>&1
  send "codex one"
  check "codex: the most recently active session is told, and only it" 'within "[ -s \"$T/codex.calls\" ]" && [ "$(cat "$T/codex.calls")" = "queue --thread c-one --message You have mail in .ai/mail/inbox/." ] && sleep 1 && [ "$(pushes)" = 2 ]'
  check "codex: once told, it's busy" '[ "$(state c-one)" = busy ]'
  send "codex two"
  sleep 2
  check "codex: none while the most recent is busy, not even another" '[ "$(wc -l <"$T/codex.calls" | tr -d " ")" = 1 ] && [ "$(pushes)" = 2 ]'
  hook session-end c-one "$P/alpha" codex >/dev/null 2>&1
  send "channel four"
  check "channel: once that session ends, the next one" 'within "[ \"\$(pushes)\" = 3 ]"'

  exec 3>&-
  check "channel: ends with its input, and clears up its pipe" 'within "! kill -0 $chan 2>/dev/null" && [ ! -e "$R/s-chan.pipe" ] && [ ! -e "$R/s-chan.chan" ]'

  # A channel whose process is there but doesn't read its pipe: delivery
  # doesn't wait on it
  sleep 60 &
  stuck=$!
  mkfifo "$R/s-stuck.pipe" && printf '%s\n' "$stuck" >"$R/s-stuck.chan"
  printf 'root=%s\nagent=claude\nid=s-stuck\nby=dot-ai\nstate=idle\n' "$(cd "$P/alpha" && pwd -P)" >"$SD/s-stuck.session"
  send "channel five" &
  sender=$!
  check "channel: one that doesn't read holds no delivery up" 'within "! kill -0 $sender 2>/dev/null"'
  kill "$stuck" 2>/dev/null
  rm -f "$R/s-stuck.pipe" "$R/s-stuck.chan" "$SD/s-stuck.session"
  # One that ended without clearing up: a session's start does
  sh -c ':' &
  gone=$!
  wait "$gone"
  mkfifo "$R/s-gone.pipe" && printf '%s\n' "$gone" >"$R/s-gone.chan"
  check "record: a session's start clears up an ended channel's pipe" 'hook session-start s-next "$P/alpha" claude >/dev/null 2>&1; [ ! -e "$R/s-gone.pipe" ] && [ ! -e "$R/s-gone.chan" ]'

  # Started without this plugin's channel: it doesn't listen
  hook session-start s-plain "$P/alpha" claude >/dev/null 2>&1
  out=$( (printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/initialized"}'
    sleep 2
    send "channel six"
    sleep 2) | CLAUDE_CODE_SESSION_ID=s-plain CLAUDE_PROJECT_DIR=$P/alpha sh -c "$SH \"$M\" channel; :" claude)
  check "channel: not where the session wasn't started with it" '[ -z "$out" ] && [ ! -e "$R/s-plain.pipe" ]'

  # Telling through a session's runner, `<by> tell <id>`, with a stand-in
  # runner that exits as $T/aix.status says
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/aix.calls"\nexit "$(cat "%s/aix.status")"\n' "$T" "$T" >"$T/fake/aix"
  chmod +x "$T/fake/aix"
  rm -f "$SD"/*.session
  : >"$T/codex.calls"
  : >"$T/aix.calls"
  arec() { # KEY BY AGENT [PID]
    { printf 'root=%s\nagent=%s\nid=%s\nby=%s\n' "$(cd "$P/alpha" && pwd -P)" "$3" "$1" "$2"
      [ -z "${4:-}" ] || printf 'pid=%s\n' "$4"
      printf 'state=idle\n'; } >"$SD/$1.session"
  }
  arec r-old dot-ai codex
  touch -t 202601010000 "$SD/r-old.session"
  arec r-aix aix claude
  printf '0\n' >"$T/aix.status"
  send "runner one"
  check "runner: one the person doesn't allow isn't run; the next newest is told" '[ ! -s "$T/aix.calls" ] && within "[ -s \"$T/codex.calls\" ]" && grep -q "^queue --thread r-old " "$T/codex.calls"'
  git config --file "$T/gitconfig" ai.runner aix
  arec r-old dot-ai codex
  touch -t 202601010000 "$SD/r-old.session"
  : >"$T/codex.calls"
  send "runner two"
  check "runner: an allowed one is run, its session told" '[ "$(cat "$T/aix.calls")" = "tell r-aix" ] && sleep 1 && [ ! -s "$T/codex.calls" ]'
  printf '4\n' >"$T/aix.status"
  send "runner three"
  check "runner: 4, it can't push: nothing more" '[ "$(wc -l <"$T/aix.calls" | tr -d " ")" = 2 ] && sleep 1 && [ ! -s "$T/codex.calls" ]'
  printf '3\n' >"$T/aix.status"
  send "runner four"
  check "runner: 3, not open: the next newest" 'within "[ -s \"$T/codex.calls\" ]" && grep -q "^queue --thread r-old " "$T/codex.calls"'
  printf '7\n' >"$T/aix.status"
  arec r-old dot-ai codex
  touch -t 202601010000 "$SD/r-old.session"
  : >"$T/codex.calls"
  out=$( (cd "$P/beta" && printf 'Hi.\n' | dotai send @alpha "runner five"); printf 'status %s\n' $?)
  check "runner: one that fails is said, but the mail went" 'printf "%s\n" "$out" | grep -q "^not told: .*aix tell r-aix exited 7" && printf "%s\n" "$out" | grep -qx "status 0" && sleep 1 && [ ! -s "$T/codex.calls" ]'
  printf 'Hi.\n' >"$P/beta/.ai/mail/outbox/20261111-120000Z-@alpha--runner-stop.md"
  check "runner: its failure, told by the Stop that delivered" 'hook stop b-run "$P/beta" claude 2>&1 | grep -q "^dot-ai: not told: .*aix tell r-aix exited 7"'
  git config --file "$T/gitconfig" --unset-all ai.runner
  # A session whose harness's process is gone is taken as ended
  sh -c ':' &
  gone=$!
  wait "$gone"
  rm -f "$SD"/*.session
  arec r-old dot-ai codex
  touch -t 202601010000 "$SD/r-old.session"
  arec r-dead dot-ai claude "$gone"
  : >"$T/codex.calls"
  send "runner six"
  check "runner: a session whose process is gone, taken as ended" 'within "[ -s \"$T/codex.calls\" ]" && grep -q "^queue --thread r-old " "$T/codex.calls"'
  check "tell: dot-ai's, for a session not open, 3, and marks it ended" '$SH "$M" tell r-dead; [ $? -eq 3 ] && [ "$(state r-dead)" = ended ]'
  check "tell: dot-ai's, for a session it has no record of, 3" '$SH "$M" tell r-none; [ $? -eq 3 ]'
  check "tell: dot-ai's, for a busy session, 0" '$SH "$M" tell r-old; [ $? -eq 0 ]'
  arec r-plain dot-ai claude
  check "tell: dot-ai's, for an idle one it can't push to, 4" '$SH "$M" tell r-plain; [ $? -eq 4 ]'
  rm -f "$SD"/*.session
fi

# Another carrier: Arcana stays out of mail under dot-ai's; dot-ai hands
# the carrier's work to Arcana's, and refuses one it doesn't know
git config --file "$T/gitconfig" ai.carrier $OTHER
printf 'x\n' >"$A/outbox/20261015-230000Z-@beta--carried.md"
if [ "$CARRIER" = arcana ]; then
  check "carrier: deliver stays out" '! (cd "$P/alpha" && carry deliver 2>/dev/null) && [ -f "$A/outbox/20261015-230000Z-@beta--carried.md" ]'
else
  mkdir -p "$T/bin" && printf '#!/bin/sh\nprintf "handed: %%s\\n" "$*"\n' >"$T/bin/arcana" && chmod +x "$T/bin/arcana"
  check "carrier: deliver is handed to arcana" '[ "$(cd "$P/alpha" && PATH=$T/bin:$PATH && carry deliver)" = "handed: mail deliver" ] && [ -f "$A/outbox/20261015-230000Z-@beta--carried.md" ]'
  git config --file "$T/gitconfig" ai.carrier pigeon
  check "carrier: one dot-ai can't hand to is refused" '! (cd "$P/alpha" && carry deliver 2>/dev/null)'
  printf '#!/bin/sh\nprintf "pigeon: %%s\\n" "$*"\n' >"$T/bin/pigeon" && chmod +x "$T/bin/pigeon"
  check "carrier: any carrier named, handed its commands" '[ "$(cd "$P/alpha" && PATH=$T/bin:$PATH && carry receipts)" = "pigeon: mail receipts" ] && [ "$(cd "$P/alpha" && PATH=$T/bin:$PATH && carry read "#news" --after 2)" = "pigeon: mail read #news --after 2" ]'
  git config --file "$T/gitconfig" ai.carrier ../bin/pigeon
  check "carrier: a name that isn't a carrier's is refused" '! (cd "$P/alpha" && PATH=$T/bin:$PATH && carry deliver 2>&1) | grep -q "^pigeon:"'
  git config --file "$T/gitconfig" ai.carrier $OTHER
fi
check "carrier: the hooks are quiet" 'hook stop a9 "$P/alpha" claude 2>/dev/null && [ -z "$(hook prompt a9 "$P/alpha" claude)" ] && [ -f "$A/outbox/20261015-230000Z-@beta--carried.md" ] && [ -s "$A/outbox/.receipts" ]'
git config --file "$T/gitconfig" ai.carrier $CARRIER

# The person's settings come from their own git config, never a
# repository's (dot-ai's own; Arcana's to follow)
if [ "$CARRIER" = local ]; then
  git -C "$P/alpha" init -q
  git -C "$P/alpha" config ai.carrier pigeon
  check "settings: a repository's ai.carrier is ignored" '(cd "$P/alpha" && carry deliver 2>&1) | grep -q "^delivered: 20261015-230000Z-@beta--carried.md" && [ ! -f "$A/outbox/20261015-230000Z-@beta--carried.md" ]'
  check "settings: and warned of, naming the repository" '(cd "$P/alpha" && carry check 2>&1 >/dev/null) | grep -q "^dot-ai: $(cd "$P/alpha" && pwd -P) sets ai.carrier in its own git config, which is ignored"'
  check "settings: warned of once at a session's start" 'hook session-start a10 "$P/alpha" claude | grep -q "sets ai.carrier in its own git config" && hook stop a10 "$P/alpha" claude 2>/dev/null'
  git -C "$P/alpha" config ai.path "$T/nowhere"
  check "settings: a repository's ai.path is ignored" '[ "$(cd "$P/alpha" && carry find beta 2>/dev/null)" = "$P/beta" ]'
  rm -rf "$P/alpha/.git"
fi

[ "$failed" = 0 ] && printf 'all passed\n'
exit "$failed"
