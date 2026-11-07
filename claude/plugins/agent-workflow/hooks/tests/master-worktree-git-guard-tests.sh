#!/usr/bin/env bash
# Regression fixture for pretooluse-master-worktree-git-guard.sh.
# Exits non-zero on first failed expectation.

set -u
# NOTE: we deliberately don't `set -e` or `pipefail` — test_cmd captures
# expected non-zero exits as data, and `printf | HOOK` can SIGPIPE if the
# hook exits before consuming all of stdin (rare but observable on the
# boundary cases). Failures are reflected in the FAILS counter + a non-zero
# script exit at the bottom.

. "$(dirname "$0")/fixture.sh"
HOOK="$HOOKS/pretooluse-master-worktree-git-guard.sh"

if [ ! -x "$HOOK" ]; then
  echo "ERROR: hook not executable at $HOOK" >&2
  exit 2
fi

FAILS=0
PASSES=0

test_cmd() {
  local label="$1" expected="$2" cmd="$3"
  local result
  # Hermetic: the hook reads the override from the command
  # text, never the env, but clear it anyway so the suite cannot inherit
  # an operator override from the calling shell if that ever changes.
  result=$(printf '%s' "$(jq -n --arg cmd "$cmd" '{tool_name:"Bash",tool_input:{command:$cmd}}')" | env -u GOAT_ALLOW_MASTER_GIT_MUTATE -u AGENT_ALLOW_MASTER_GIT_MUTATE "$HOOK" 2>&1)
  local decision="allow"
  if [ -n "$result" ]; then
    decision=$(printf '%s' "$result" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null)
  fi
  if [ "$decision" = "$expected" ]; then
    echo "PASS  [$expected]  $label"
    PASSES=$((PASSES + 1))
  else
    echo "FAIL  expected=$expected got=$decision  $label  | cmd=$cmd"
    FAILS=$((FAILS + 1))
  fi
}

echo "== ALLOWED (mutating git with -C worktree path) =="
test_cmd "git -C worktree commit"                        allow "git -C /Users/x/repo/.claude/worktrees/foo commit -m wip"
test_cmd "git -C worktree add"                           allow "git -C /Users/x/repo/.claude/worktrees/foo add file.txt"
test_cmd "git -C worktree push"                          allow "git -C /Users/x/repo/.claude/worktrees/foo push -u origin track/foo"
test_cmd "git -C worktree merge"                         allow "git -C /Users/x/repo/.claude/worktrees/foo merge origin/main"
test_cmd "git -C worktree rebase"                        allow "git -C /Users/x/repo/.claude/worktrees/foo rebase origin/main"
test_cmd "git -C worktree pull"                          allow "git -C /Users/x/repo/.claude/worktrees/foo pull --rebase"
test_cmd "git -C worktree cherry-pick"                   allow "git -C /Users/x/repo/.claude/worktrees/foo cherry-pick abc123"
test_cmd "git -C worktree revert"                        allow "git -C /Users/x/repo/.claude/worktrees/foo revert HEAD"
test_cmd "git -C worktree am"                            allow "git -C /Users/x/repo/.claude/worktrees/foo am < patch.mbox"
test_cmd "git -C worktree mv"                            allow "git -C /Users/x/repo/.claude/worktrees/foo mv a b"
test_cmd "git -C worktree rm"                            allow "git -C /Users/x/repo/.claude/worktrees/foo rm stale.txt"
test_cmd "git -C worktree apply"                         allow "git -C /Users/x/repo/.claude/worktrees/foo apply patch.diff"
test_cmd "git -C worktree tag (create)"                  allow "git -C /Users/x/repo/.claude/worktrees/foo tag wip-1"
test_cmd "git -C worktree chain commit + push"           allow "git -C /Users/x/repo/.claude/worktrees/foo commit -m x && git -C /Users/x/repo/.claude/worktrees/foo push"

echo "== ALLOWED (read-only git or non-master cwd) =="
test_cmd "git status (no cwd)"                           allow "git status"
test_cmd "git log"                                       allow "git log --oneline -3"
test_cmd "git diff"                                      allow "git diff HEAD"
test_cmd "git fetch"                                     allow "git fetch origin"
test_cmd "git show"                                      allow "git show HEAD"
test_cmd "git branch (list)"                             allow "git branch --list"
test_cmd "git branch --show-current"                     allow "git branch --show-current"
test_cmd "git branch -a"                                 allow "git branch -a"
test_cmd "git tag (list)"                                allow "git tag --list"
test_cmd "git tag -l"                                    allow "git tag -l 'v*'"
test_cmd "git worktree add (worktree itself)"            allow "git -C /Users/x/repo worktree add /Users/x/repo/.claude/worktrees/foo -b track/foo origin/main"
test_cmd "git worktree list"                             allow "git worktree list"
test_cmd "git worktree remove"                           allow "git worktree remove .claude/worktrees/foo"
test_cmd "git rev-parse"                                 allow "git rev-parse HEAD"
test_cmd "git ls-files"                                  allow "git ls-files"
test_cmd "git remote -v"                                 allow "git remote -v"
test_cmd "git config user.name (read)"                   allow "git config user.name"
test_cmd "git stash list"                                allow "git stash list"
test_cmd "git stash show"                                allow "git stash show stash@{0}"

echo "== ALLOWED (no git at all / unrelated) =="
test_cmd "plain ls"                                      allow "ls -la"
test_cmd "find"                                          allow "find . -name '*.rs'"
test_cmd "echo"                                          allow "echo hello"
test_cmd "rm -rf /tmp/x"                                 allow "rm -rf /tmp/x"
test_cmd "OBJC env-prefix + ansible"                     allow "OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES ansible-playbook -i inventory/hosts.ini foo.yml"
test_cmd "githook-named-file (no git invocation)"        allow "cat .git/HEAD"

echo "== ALLOWED (override sentinel) =="
test_cmd "override on bare commit"                       allow "GOAT_ALLOW_MASTER_GIT_MUTATE=1 git commit -m fix"
test_cmd "override on bare push"                         allow "GOAT_ALLOW_MASTER_GIT_MUTATE=1 git push origin main"
test_cmd "override on add -A"                            allow "GOAT_ALLOW_MASTER_GIT_MUTATE=1 git add -A"
test_cmd "AGENT_ override on bare commit"                 allow "AGENT_ALLOW_MASTER_GIT_MUTATE=1 git commit -m fix"

echo "== DENIED (bare mutating git, no -C) =="
test_cmd "bare git add"                                  deny  "git add file.txt"
test_cmd "bare git add -A"                               deny  "git add -A"
test_cmd "bare git add ."                                deny  "git add ."
test_cmd "bare git commit"                               deny  "git commit -m wip"
test_cmd "bare git commit -s"                            deny  "git commit -s -m wip"
test_cmd "bare git push"                                 deny  "git push"
test_cmd "bare git push origin"                          deny  "git push origin track/foo"
test_cmd "bare git push -u"                              deny  "git push -u origin track/foo"
test_cmd "bare git merge"                                deny  "git merge origin/main"
test_cmd "bare git rebase"                               deny  "git rebase origin/main"
test_cmd "bare git pull"                                 deny  "git pull --rebase"
test_cmd "bare git cherry-pick"                          deny  "git cherry-pick abc123"
test_cmd "bare git revert"                               deny  "git revert HEAD"
test_cmd "bare git am"                                   deny  "git am < patch.mbox"
test_cmd "bare git mv"                                   deny  "git mv a b"
test_cmd "bare git rm"                                   deny  "git rm stale.txt"
test_cmd "bare git apply"                                deny  "git apply patch.diff"

echo "== DENIED (cd-chain pattern — the actual incident shape) =="
test_cmd "cd worktree && git add -A (cd-chain)"          deny  "cd .claude/worktrees/foo && git add -A && git commit -m wip"
test_cmd "cd absolute && git commit (cd-chain)"          deny  "cd /Users/x/repo/.claude/worktrees/foo && git commit -m wip"
test_cmd "cd outside && git push (cd-chain)"             deny  "cd /tmp && git push origin x"

echo "== DENIED (-C points outside worktree dir) =="
test_cmd "-C master root commit"                         deny  "git -C /Users/x/repo commit -m fix"
test_cmd "-C tmp commit"                                 deny  "git -C /tmp commit -m fix"
test_cmd "-C random commit"                              deny  "git -C ~/somewhere commit -m fix"

echo "== DENIED (chained: one safe + one bare) =="
test_cmd "good then bare"                                deny  "git -C /repo/.claude/worktrees/foo add file && git commit -m wip"
test_cmd "bare then good"                                deny  "git add file && git -C /repo/.claude/worktrees/foo commit -m wip"

echo "== DENIED (allow-direction gaps, #455) =="
# 1. The substring fast path matched before `..` was resolved, so a path whose
#    effective target is the master worktree satisfied it.
test_cmd "traversal-spoofed -C out of worktree"          deny  "git -C /Users/x/repo/.claude/worktrees/foo/../.. commit -m spoof"
test_cmd "traversal-spoofed -C one level up"             deny  "git -C /Users/x/repo/.claude/worktrees/foo/.. commit -m spoof"
# 2. git applies -C cumulatively; the second one used to land where the
#    subcommand was expected, so the segment failed the match and was skipped.
test_cmd "second -C escapes the worktree"                deny  "git -C /Users/x/repo/.claude/worktrees/foo -C .. commit -m x"
test_cmd "second -C absolute overrides the first"        deny  "git -C /Users/x/repo/.claude/worktrees/foo -C /tmp commit -m x"
# 3. Only the space form of --git-dir / --work-tree was matched, so the equals
#    form failed the match and was skipped.
test_cmd "--git-dir= master git dir"                     deny  "git --git-dir=/Users/x/repo/.git commit -m x"
test_cmd "--work-tree= master root"                      deny  "git --work-tree=/Users/x/repo commit -m x"
test_cmd "--work-tree= master root with safe -C"         deny  "git --work-tree=/Users/x/repo -C /Users/x/repo/.claude/worktrees/foo commit -m x"
# 4. A quoted hop was joined as raw text, so the quotes ended up MID-path where
#    the end-only strip could not reach them and `'..'` read as a directory name.
test_cmd "quoted second -C (single)"                     deny  "git -C /Users/x/repo/.claude/worktrees/foo -C '..' commit -m x"
test_cmd "quoted second -C (double)"                     deny  "git -C /Users/x/repo/.claude/worktrees/foo -C \"..\" commit -m x"
test_cmd "quoted traversal hop"                          deny  "git -C /Users/x/repo/.claude/worktrees/foo -C '../..' commit -m x"
# 5. An invocation the grammar cannot parse is refused, not skipped. -P and
#    --literal-pathspecs both commit in master; the quoted -c value used to make
#    the parser read the value's tail as the subcommand and miss `commit`.
test_cmd "-P (short --no-pager)"                         deny  "git -P commit -m x"
test_cmd "--bare"                                        deny  "git --bare commit -m x"
test_cmd "--literal-pathspecs"                           deny  "git --literal-pathspecs commit -m x"
test_cmd "-c value with a space (double-quoted)"         deny  "git -c user.name=\"a b\" commit -m x"
test_cmd "-c value with a space (single-quoted)"         deny  "git -c 'user.name=a b' commit -m x"
test_cmd "-c whole arg quoted"                           deny  "git -c \"user.name=a b\" commit -m x"

# 6. Quotes in the MIDDLE of a word survived an end-only strip; bash joins
#    foo/'..' into foo/.., so each of these commits on master. Verified against
#    a real `git worktree add`.
test_cmd "mid-word quoted traversal in -C"               deny  "git -C /Users/x/repo/.claude/worktrees/foo/'..'/.. commit -m x"
test_cmd "mid-word double-quoted traversal in -C"        deny  "git -C /Users/x/repo/.claude/worktrees/foo/\"..\"/.. commit -m x"
test_cmd "mid-word quoted traversal in second -C hop"    deny  "git -C /Users/x/repo/.claude/worktrees/foo -C ../'..' commit -m x"
test_cmd "mid-word quoted traversal in --git-dir="       deny  "git -C /Users/x/repo/.claude/worktrees/foo --git-dir=/Users/x/repo/.git/worktrees/'..' commit -m x"
test_cmd "mid-word quoted traversal in --work-tree="     deny  "git -C /Users/x/repo/.claude/worktrees/foo --work-tree=/Users/x/repo/.claude/worktrees/foo/'..'/.. commit -m x"
# 7. A hop the hook cannot expand is unresolvable, not relative. Joined as
#    text, `<wt>/$HOME` kept the marker while bash expanded $HOME to an
#    absolute path and git committed on master.
test_cmd "second -C is an unexpanded variable"           deny  "git -C /Users/x/repo/.claude/worktrees/foo -C \$HOME commit -m x"
test_cmd "second -C is a quoted variable"                deny  "git -C /Users/x/repo/.claude/worktrees/foo -C \"\$X\" commit -m x"
test_cmd "second -C is a command substitution"           deny  "git -C /Users/x/repo/.claude/worktrees/foo -C \$(pwd) commit -m x"
test_cmd "second -C is a backtick substitution"          deny  "git -C /Users/x/repo/.claude/worktrees/foo -C \`pwd\` commit -m x"
test_cmd "--work-tree= is an unexpanded variable"        deny  "git -C /Users/x/repo/.claude/worktrees/foo --work-tree=\$X commit -m x"
test_cmd "--git-dir= is an unexpanded variable"          deny  "git -C /Users/x/repo/.claude/worktrees/foo --git-dir=\$X commit -m x"

echo "== STILL ALLOWED (the same shapes, staying inside a worktree) =="
test_cmd "mid-word quoted subdir stays inside"           allow "git -C /Users/x/repo/.claude/worktrees/foo/'sub dir' commit -m x"
test_cmd "quoted second hop stays inside"                allow "git -C /Users/x/repo/.claude/worktrees/foo -C '../bar' commit -m x"
test_cmd "-C worktree subdir"                            allow "git -C /Users/x/repo/.claude/worktrees/foo/sub commit -m x"
test_cmd "-C worktree with trailing slash"               allow "git -C /Users/x/repo/.claude/worktrees/foo/ commit -m x"
test_cmd "second -C stays inside worktrees"              allow "git -C /Users/x/repo/.claude/worktrees/foo -C ../bar commit -m x"
test_cmd "--no-pager before -C worktree"                 allow "git --no-pager -C /Users/x/repo/.claude/worktrees/foo commit -m x"
test_cmd "-c flag with = before -C worktree"             allow "git -c user.name=t -C /Users/x/repo/.claude/worktrees/foo commit -m x"
test_cmd "-c quoted value before -C worktree"            allow "git -c user.name=\"a b\" -C /Users/x/repo/.claude/worktrees/foo commit -m x"
test_cmd "quoted -C worktree path"                       allow "git -C '/Users/x/repo/.claude/worktrees/foo' commit -m x"
test_cmd "-C worktree path containing a space"           allow "git -C \"/Users/x/my repo/.claude/worktrees/foo\" commit -m x"
# Flags with no subcommand name nothing to mutate, so the fail-closed branch
# must not swallow them.
test_cmd "git --version (flags only)"                    allow "git --version"
test_cmd "git --help (flags only)"                       allow "git --help"

echo "== LINKED-WORKTREE OVERRIDES (the correct shapes must not be refused) =="
# A linked worktree has no .git DIRECTORY — its .git is a file reading
# `gitdir: <main>/.git/worktrees/<name>` — so the correct --git-dir for a
# worktree lives under the MAIN repo's .git and carries no worktrees marker.
# All three of these were verified against a real `git worktree add`: each
# commits into the worktree, never into master.
test_cmd "--git-dir= the worktree's real git dir"        allow "git -C /Users/x/repo/.claude/worktrees/foo --git-dir=/Users/x/repo/.git/worktrees/foo commit -m x"
test_cmd "--git-dir=.git relative to -C"                 allow "git -C /Users/x/repo/.claude/worktrees/foo --git-dir=.git commit -m x"
test_cmd "--work-tree=. relative to -C"                  allow "git -C /Users/x/repo/.claude/worktrees/foo --work-tree=. commit -m x"
test_cmd "--work-tree=. with no -C still denied"         deny  "git --work-tree=. commit -m x"

echo "== EXTERNAL LINKED WORKTREES (GH #256) =="
# A linked worktree OUTSIDE the repo root (git worktree add ../<name>) is an
# explicit non-master target and must be accepted; the MAIN worktree of any
# repo and non-worktree paths stay refused. Scratch repo keeps this hermetic.
SCRATCH="$(mktemp -d)"
git init -q "$SCRATCH/main"
git -C "$SCRATCH/main" -c user.email=t@t.test -c user.name=t commit -q --allow-empty -m init
git -C "$SCRATCH/main" worktree add -q "$SCRATCH/ext-wt" >/dev/null 2>&1
mkdir -p "$SCRATCH/ext-wt/sub"
test_cmd "-C external linked worktree commit"            allow "git -C $SCRATCH/ext-wt commit -s -m wip"
test_cmd "-C external linked worktree add -A"            allow "git -C $SCRATCH/ext-wt add -A"
test_cmd "-C external linked worktree apply --3way"      allow "git -C $SCRATCH/ext-wt apply --3way patch.diff"
test_cmd "-C external linked worktree push"              allow "git -C $SCRATCH/ext-wt push -u origin track/x"
test_cmd "-C subdir of external linked worktree"         allow "git -C $SCRATCH/ext-wt/sub commit -m wip"
test_cmd "-C scratch MAIN worktree still denied"         deny  "git -C $SCRATCH/main commit -m wip"
test_cmd "-C existing non-repo dir still denied"         deny  "git -C $SCRATCH commit -m wip"
# The real master worktree of THIS repo must stay refused (resolved via the
# common dir so the expectation holds when the tests run from a linked
# worktree too).
MASTER_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"
test_cmd "-C this repo's master root still denied"       deny  "git -C $MASTER_ROOT commit -m wip"
rm -rf "$SCRATCH"

echo "== QUOTED HEREDOC BODIES + STRING LITERALS (GH #256) =="
HD_ONLY=$'cat <<\'EOF\' > /tmp/gg-heredoc-test\ngit commit -m wip\ngit push origin main\nEOF'
test_cmd "git text only inside quoted heredoc body"      allow "$HD_ONLY"
HD_TABBED=$'cat <<-\'DOC\' > /tmp/gg-heredoc-test\n\tgit add -A\n\tDOC'
test_cmd "git text inside <<-'DOC' tab-indented body"    allow "$HD_TABBED"
HD_PLUS_SAFE=$'git -C /Users/x/repo/.claude/worktrees/foo commit -m x\ncat <<\'MSG\'\ngit add -A\nMSG'
test_cmd "safe -C commit + heredoc-embedded git text"    allow "$HD_PLUS_SAFE"
HD_PLUS_BARE=$'cat <<\'EOF\' > /tmp/gg-heredoc-test\ngit commit -m inside\nEOF\ngit commit -m real'
test_cmd "bare git AFTER heredoc terminator still denied" deny "$HD_PLUS_BARE"
test_cmd "separator inside double-quoted literal"        allow "echo \"run; git commit -m x later\""
test_cmd "git text inside single-quoted literal"         allow "echo 'then git push origin main'"
test_cmd "command position after && still detected"      deny  "true && git commit -m wip"
test_cmd "command position after pipe still detected"    deny  "cat patch.diff | git apply"

echo "== COMMENTS + QUOTE-STATE DIVERGENCE (GH #256) =="
# Text bash parses as a comment, an unquoted-heredoc body, or a string
# literal must not corrupt the quote tracker: in each deny case below, real
# bash EXECUTES the bare mutating git, so the guard must still see it.
CMT_APOS=$'# don\'t touch master\ngit add -A'
test_cmd "bare git after apostrophe-in-comment line"     deny  "$CMT_APOS"
CMT_TRAIL=$'git -C /r/.claude/worktrees/x commit -m ok # it\'s fine\ngit push origin main'
test_cmd "bare git after trailing apostrophe comment"    deny  "$CMT_TRAIL"
CMT_TEXT=$'# run git commit later\necho hi'
test_cmd "git text inside a comment only"                allow "$CMT_TEXT"
test_cmd "hash mid-word is not a comment"                deny  "echo msg#tag && git commit -m wip"
HD_UNQ_APOS=$'cat <<EOF > /tmp/gg-heredoc-test\ndon\'t\nEOF\ngit commit -m x'
test_cmd "bare git after unquoted-heredoc apostrophe"    deny  "$HD_UNQ_APOS"
HD_UNQ_BODY=$'cat <<EOF > /tmp/gg-heredoc-test\ngit commit -m x\nEOF'
test_cmd "unquoted heredoc body still scanned"           deny  "$HD_UNQ_BODY"
HD_QUO_APOS=$'cat <<\'EOF\' > /tmp/gg-heredoc-test\ndon\'t run git commit here\nEOF'
test_cmd "quoted heredoc apostrophe body still dropped"  allow "$HD_QUO_APOS"
FAKE_OPEN=$'echo "docs use <<\'EOF\' style"\ngit commit -m x\nEOF'
test_cmd "heredoc opener inside string literal is data"  deny  "$FAKE_OPEN"
# ANSI-C quoting: \' inside $'...' is an ESCAPED apostrophe — bash runs the
# string to the final ' and then EXECUTES the next line's bare git. Closing
# the tracker at \' re-opened it at the real terminator and swallowed that
# git as string data (false ALLOW found in review).
ANSI_APOS=$'echo $\'don\\\'t stop\'\ngit commit -m x'
test_cmd "bare git after ANSI-C escaped-apostrophe string" deny "$ANSI_APOS"
ANSI_DATA=$'echo $\'x; git commit -m y\''
test_cmd "separator inside ANSI-C string literal"        allow "$ANSI_DATA"
# Backslash-quoted heredoc delimiter (<<\EOF) is quoted to bash like
# <<'EOF': body literal, terminator EOF. Unrecognized, the body apostrophe
# corrupted the quote tracker and swallowed the post-terminator bare git
# (false ALLOW found in review).
HD_BSL_APOS=$'cat <<\\EOF > /tmp/gg-heredoc-test\ndon\'t\nEOF\ngit commit -m x'
test_cmd "bare git after backslash-heredoc apostrophe"   deny  "$HD_BSL_APOS"
HD_BSL_BODY=$'cat <<\\EOF > /tmp/gg-heredoc-test\ngit commit -m inside\nEOF'
test_cmd "git text inside backslash-heredoc body dropped" allow "$HD_BSL_BODY"
# <<< is a herestring, not a heredoc opener: the word after it is an
# ordinary argument and bash EXECUTES the following lines. Skipping only
# the first `<` of `<<<` let the scanner re-match <<'word' one char later
# and drop those lines as a phantom quoted body (false ALLOW found in
# review).
HS_QUOTED=$'read -r b <<< \'value\'\ngit commit -m x'
test_cmd "bare git after herestring <<< 'word'"          deny  "$HS_QUOTED"
HS_DELIM=$'cat <<<\'EOF\'\ngit commit -m x\nEOF'
test_cmd "bare git between <<<'EOF' and stray EOF line"  deny  "$HS_DELIM"
HS_DATA='grep -q x <<< "then git push origin main"'
test_cmd "git text inside herestring word"               allow "$HS_DATA"
# Non-word delimiters (E-O-F) are real heredocs to bash; the \w-only opener
# regex left them unrecognized, so the body apostrophe corrupted the quote
# tracker and swallowed the post-terminator bare git (false ALLOW found in
# review).
HD_DASH_APOS=$'cat <<\'E-O-F\' > /tmp/gg-heredoc-test\ndon\'t\nE-O-F\ngit commit -m x'
test_cmd "bare git after dashed-delimiter heredoc"       deny  "$HD_DASH_APOS"
HD_DASH_BODY=$'cat <<\'E-O-F\' > /tmp/gg-heredoc-test\ngit commit -m inside\nE-O-F'
test_cmd "git text inside dashed-delimiter quoted body"  allow "$HD_DASH_BODY"
# Arithmetic left-shift with a digit operand registers a phantom unquoted
# opener whose "body" (the following lines) gets the conservative
# unquoted-body scan — deny-direction, so both verdicts must hold: the
# bare git is still caught, the safe -C form still passes.
AR_SHIFT=$'echo $((1<<2))\ngit commit -m x'
test_cmd "bare git after arithmetic left-shift"          deny  "$AR_SHIFT"
AR_SHIFT_OK=$'echo $((1<<2))\ngit -C /r/.claude/worktrees/x commit -m ok'
test_cmd "safe -C commit after arithmetic left-shift"    allow "$AR_SHIFT_OK"
# A pure-digit delimiter (cat <<2) is a REAL heredoc to bash: the old
# arithmetic heuristic skipped the opener, so the body apostrophe corrupted
# the quote tracker and swallowed the post-terminator bare git (false ALLOW
# found in review). Registered as an unquoted opener, the terminator line
# hands the rest back to the normal scan.
HD_DIGIT_APOS=$'cat <<2 > /tmp/gg-heredoc-test\ndon\'t\n2\ngit commit -m x'
test_cmd "bare git after digit-delimiter heredoc"        deny  "$HD_DIGIT_APOS"
HD_DIGIT_SAFE=$'cat <<2 > /tmp/gg-heredoc-test\ndon\'t\n2\ngit -C /r/.claude/worktrees/x commit -m ok'
test_cmd "safe -C commit after digit-delimiter heredoc"  allow "$HD_DIGIT_SAFE"
# An EMPTY quoted delimiter (<<'' — body ends at the first empty line) is
# also a real heredoc; unrecognized (the delimiter regex demanded ≥1 char),
# its body apostrophe corrupted the quote tracker the same way (false ALLOW
# found in review).
HD_EMPTY_APOS=$'cat <<\'\' > /tmp/gg-heredoc-test\ndon\'t run git commit here\n\ngit commit -m x'
test_cmd "bare git after empty-delimiter heredoc"        deny  "$HD_EMPTY_APOS"
HD_EMPTY_BODY=$'cat <<\'\' > /tmp/gg-heredoc-test\ngit commit -m inside\n\necho done'
test_cmd "git text inside empty-delimiter quoted body"   allow "$HD_EMPTY_BODY"
# Unquoted heredoc bodies EXECUTE when fed to a shell (bash <<EOF), so the
# conservative body scan must split at separators too: judging only the
# line's START let `true; git commit` — and the safe-prefixed
# `git -C <wt> add; git commit` — through (false ALLOW found in review).
HD_UNQ_COMPOUND=$'bash <<EOF\ntrue; git commit -m x\nEOF'
test_cmd "compound bare git in unquoted heredoc body"    deny  "$HD_UNQ_COMPOUND"
HD_UNQ_PREFIX=$'bash <<EOF\ngit -C /r/.claude/worktrees/x add f; git commit -m x\nEOF'
test_cmd "safe-prefix then bare git in unquoted body"    deny  "$HD_UNQ_PREFIX"
HD_UNQ_2SAFE=$'bash <<EOF\ngit -C /r/.claude/worktrees/x add f; git -C /r/.claude/worktrees/x commit -m x\nEOF'
test_cmd "two safe -C commands on one unquoted body line" allow "$HD_UNQ_2SAFE"
# `\\$'...'` is an ESCAPED BACKSLASH followed by a real ANSI-C string: bash
# runs the string to the final ' and EXECUTES the next line's bare git.
# Inspecting buf positionally couldn't tell `\$'` (escaped dollar → plain
# quote) from `\\$'` (false ALLOW found in review); escape pairs are now
# consumed atomically so only an unescaped $ enables ANSI-C mode.
ANSI_DBL_BSL=$'echo \\\\$\'don\\\'t stop\'\ngit commit -m x'
test_cmd "bare git after escaped-backslash ANSI string"  deny  "$ANSI_DBL_BSL"
ESC_DOLLAR=$'echo \\$\'x; git commit -m y\''
test_cmd "escaped-dollar plain-quoted separator is data" allow "$ESC_DOLLAR"

echo "== MARKER GATING =="
PLAIN_RESULT=$(cd "$FIX_PLAIN" && printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | "$HOOK")
if [ -z "$PLAIN_RESULT" ]; then echo "PASS  [allow]  repo without the marker: guard off"; PASSES=$((PASSES + 1))
else echo "FAIL  guard fired in a repo without the marker"; FAILS=$((FAILS + 1)); fi
printf 'master_readonly: false\n' >> "$FIX_REPO/.claude/agent-workflow.yaml"
test_cmd "master_readonly: false switches the guard off"  allow "git commit -m x"
sed -i.bak '/^master_readonly:/d' "$FIX_REPO/.claude/agent-workflow.yaml"
printf 'worktrees_dir: wt\n' > "$FIX_REPO/.claude/agent-workflow.yaml"
test_cmd "custom worktrees_dir accepted"                 allow "git -C /Users/x/repo/wt/foo commit -m x"
test_cmd "default dir refused under custom worktrees_dir" deny "git -C /Users/x/repo/.claude/worktrees/foo commit -m x"
printf 'worktrees_dir: .claude/worktrees\n' > "$FIX_REPO/.claude/agent-workflow.yaml"

echo "== NON-BASH PASSTHROUGH =="
# Non-Bash tool: hook must produce no output (empty = allow).
NONBASH_RESULT=$(printf '%s' '{"tool_name":"Read","tool_input":{"file_path":"/x"}}' | "$HOOK")
if [ -z "$NONBASH_RESULT" ]; then
  echo "PASS  [allow]  Non-Bash tool produces no output"
  PASSES=$((PASSES + 1))
else
  echo "FAIL  Non-Bash tool produced output: $NONBASH_RESULT"
  FAILS=$((FAILS + 1))
fi

EDIT_RESULT=$(printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"/x","old_string":"a","new_string":"b"}}' | "$HOOK")
if [ -z "$EDIT_RESULT" ]; then
  echo "PASS  [allow]  Edit tool produces no output (Edit-class is the other guard's surface)"
  PASSES=$((PASSES + 1))
else
  echo "FAIL  Edit tool produced output: $EDIT_RESULT"
  FAILS=$((FAILS + 1))
fi

echo ""
echo "PASSES: $PASSES   FAILS: $FAILS"
if [ "$FAILS" -gt 0 ]; then
  exit 1
fi
