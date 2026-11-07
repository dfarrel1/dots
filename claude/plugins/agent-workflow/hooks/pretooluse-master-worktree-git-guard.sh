#!/usr/bin/env bash
# PreToolUse hook (opt-in by marker) — refuse mutating git commands on the Bash
# tool that would land in the master (main) worktree.
#
# Active only when the repo carries .claude/agent-workflow.yaml and its
# `master_readonly` is not `false`.
#
# Rule: every mutating git op carries `git -C <absolute-worktree-path>`, where the
# path is inside the marker's `worktrees_dir` (default .claude/worktrees/<name>/)
# or is any LINKED worktree (one that is not the main worktree of its repo, e.g.
# `git worktree add ../<name>`). Bare `git add|commit|push|am|merge|rebase|
# cherry-pick|revert|pull|mv|rm|apply|tag|notes` are refused: the Bash tool's cwd
# does not persist between calls, so a bare command silently targets master.
#
# Allows: read-only git (status, log, diff, fetch, show, ...), commands with no
# git, and the override below.
#
# Fails closed: a git invocation the flag grammar cannot parse, and a -C /
# --git-dir / --work-tree value that cannot be resolved statically (an
# unexpanded $VAR, a backtick, an unbalanced quote), are refused with a reason
# naming the word. Rewrite with a literal, unquoted worktree path.
#
# Operator override, per invocation, in the command string:
#   AGENT_ALLOW_MASTER_GIT_MUTATE=1 git ...      (alias GOAT_ALLOW_MASTER_GIT_MUTATE=1)
#
# Input: JSON on stdin (Claude Code PreToolUse schema).
# Output: JSON on stdout. Exit 0 always; permissionDecision controls allow/deny.
#
# bash-3.2 compatibility (load-bearing): the two big here-docs (the Python
# analyzer + the refusal text) are loaded via `read -r -d ''` instead of a
# `"$(cat <<...)"` command substitution. macOS bash 3.2 mis-parses a here-doc
# nested inside "$( ... )" and aborts at parse time, and a failing PreToolUse
# hook denies the tool call, so the broken form blocks every Bash call. Do not
# reintroduce the substitution form.

set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

aw_has_marker || exit 0
[ "$(aw_get master_readonly true)" = "false" ] && exit 0
aw_repo_registers pretooluse-master-worktree-git-guard.sh && exit 0

WT_DIR="$(aw_get worktrees_dir .claude/worktrees)"
WT_DIR="${WT_DIR%/}"

INPUT="$(cat)"

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
if [ -z "$CMD" ]; then
  exit 0
fi

# Per-invocation operator override: an assignment in the command itself.
if aw_cmd_has_override AGENT_ALLOW_MASTER_GIT_MUTATE GOAT_ALLOW_MASTER_GIT_MUTATE "$CMD"; then
  exit 0
fi

# Scan the command for mutating git ops + check each carries -C with a
# worktree path. Python is available in the hook env and gives a saner
# parser than nested bash regex.
#
# The analyzer script is loaded into a variable via `read -r -d ''` (NOT a
# `"$(python3 <<…)"` command substitution) to avoid the bash-3.2 heredoc-in-
# command-substitution parse bug. We then run it with `python3 -c` and pass
# $CMD through the CMD_INPUT env var (the script reads it from os.environ).
read -r -d '' PY_ANALYZER <<'PY' || true
import re, os, json, shlex, subprocess

cmd = os.environ.get("CMD_INPUT", "")
WT_MARK = "/" + os.environ.get("WT_DIR", ".claude/worktrees").strip("/") + "/"

# Subcommands that mutate local state in a way that could pollute master
# if the cwd is wrong. `reset`/`restore`/`clean`/`stash`/`branch -D` are
# covered by the destructive-git guard separately so we don't double-fire
# on them. `fetch` is read-only-ish (refs only), allow. `checkout`/`switch`
# CAN mutate but require a path arg; the destructive-git guard catches
# the `.`/`-- .` cases. We focus on operations that create commits or
# push refs from cwd-derived intent.
MUTATING = {
    "add", "commit", "am",
    "push",                  # mutates remote, sourced from cwd-derived branch
    "merge", "rebase",
    "cherry-pick", "revert",
    "pull",                  # equivalent to fetch + merge
    "mv", "rm",              # tree mutations
    "apply",                 # patch apply against cwd
    "tag",                   # creates refs from cwd HEAD
    "notes",                 # mutates refs
}

# Read-only subcommands explicitly allowed (informational + lookup).
READ_ONLY = {
    "status", "log", "diff", "show", "blame", "ls-files", "ls-tree",
    "rev-parse", "rev-list", "for-each-ref", "show-ref", "describe",
    "fetch", "config", "remote", "branch", "tag",  # tag re-listed read-only below
    "worktree", "stash", "reflog", "shortlog", "cat-file",
    "grep", "bisect",  # bisect is interactive-ish but read-only
    "submodule", "annotate", "verify-commit", "verify-tag",
    "check-ref-format", "check-attr", "check-ignore",
    "config", "help", "version",
    "init", "clone",  # init/clone don't operate against an existing master
}
# Some subcommands appear in both lists (tag, branch, worktree, stash) —
# the difference is the FLAGS. We resolve below.

# git's own global flags, the ones that can sit between `git` and the
# subcommand. Every value-taking flag accepts both the space and the `=` form,
# and -C is here rather than in a single optional slot so a repeated -C cannot
# push the subcommand out of the match.
#
# VALUE is a whole shell word, quoted chunks included, because the quotes can
# sit anywhere in it. `\S+` stopped at the space inside `-c user.name="a b"`,
# leaving `b"` — which the subcommand group then matched as the subcommand `b`,
# a name in neither the mutating nor the read-only set, so the segment fell
# through to allow. git accepts that command and runs it in the master
# worktree: verified, it moved master's HEAD.
#
# The trailing catch-all arm takes any other global flag, with or without a
# value. It is not the guard's edge any more: an invocation this grammar cannot
# parse is now a finding rather than a skip (see the fail-closed branch below),
# so a flag missing from this list costs a rewrite, never a silent allow.
VALUE = r"(?:[^\s'\"]|'[^']*'|\"[^\"]*\")+"
GLOBAL_FLAG = (
    r"(?:-c(?:\s+|=)" + VALUE
    + r"|--git-dir(?:\s+|=)" + VALUE
    + r"|--work-tree(?:\s+|=)" + VALUE
    + r"|--namespace(?:\s+|=)" + VALUE
    + r"|-C\s+" + VALUE
    + r"|--[\w-]+=" + VALUE
    + r"|--[\w-]+"
    + r"|-[A-Za-z])"
)
INVOCATION = re.compile(r"git\s+(?:" + GLOBAL_FLAG + r"\s+)*(\w[\w-]*)")

# Split the command into segments at command separators, modeling what bash
# EXECUTES rather than what the text contains. Three constructs
# are tracked together in ONE pass — tracking them separately let text that
# bash never parses as quotes reach the quote tracker and corrupt the scan
# of everything after it:
#
#   - Quotes: a `;`/`&&`/`|` inside a string literal is data, not a command
#     boundary; splitting on it made `echo "x; git commit"` look like a bare
#     mutating git at command position. ANSI-C quoting ($'...') is tracked
#     as its own mode: `\'` inside it is an escaped apostrophe, not the
#     terminator.
#   - Comments: an unquoted `#` starting a word comments out the rest of the
#     line. Without this, an apostrophe in a comment (`# don't ...`) flipped
#     the quote state and swallowed the NEXT line's real bare `git commit` —
#     a false ALLOW in exactly the accident class this guard exists for.
#   - Heredocs: openers are recognized only OUTSIDE quotes and comments
#     (`echo "<<'EOF'"` is data, not an opener). A quoted-delimiter body
#     (<<'EOF', <<"EOF", or the backslash form <<\EOF — all quoted to
#     bash) is literal text the shell never executes — dropped. An
#     unquoted-delimiter body undergoes expansion, so it keeps the
#     conservative treatment: every body line is split at separators and
#     scanned like top-level text (a rare false deny beats guessing) — but
#     the body stays OUT of the quote tracker, so prose like `don't` in a
#     generated file can't swallow the commands after the terminator.
#
# We don't track cd-inferred cwd: the discipline (feedback_always_use_git_c)
# is "always use -C explicitly". `cd && git` is treated identically to `git`.
def split_segments(text: str):
    segs, buf, i, n, quote = [], [], 0, len(text), ""
    ansi = False  # inside $'...' — backslash escapes apply, incl. \'
    pending = []  # heredocs opened on the current line: (delim, strip_tabs, quoted)
    while i < n:
        ch = text[i]
        if quote:
            if ch == "\\" and (quote == '"' or ansi) and i + 1 < n:
                buf.append(ch); buf.append(text[i + 1]); i += 2; continue
            if ch == quote:
                quote = ""; ansi = False
            buf.append(ch); i += 1; continue
        if ch in ("'", '"'):
            # $'...' is ANSI-C quoting: \' inside it is an ESCAPED apostrophe,
            # not the terminator. Treating it as a plain single quote closed
            # the tracker early and re-opened it at the real terminator,
            # swallowing a following bare `git commit` as string data (false
            # ALLOW). The `$` itself must be unescaped (`\$'` is a literal
            # dollar followed by an ordinary single-quoted string) — escape
            # pairs land in buf as ONE element, so a bare "$" here is
            # guaranteed unescaped.
            ansi = (ch == "'" and bool(buf) and buf[-1] == "$")
            quote = ch; buf.append(ch); i += 1; continue
        if ch == "\\" and i + 1 < n:
            # Consumed as ONE buf element so an escape pair can never be
            # misread as its second char standing alone: inspecting buf
            # positionally couldn't tell `\$'` (escaped dollar → plain
            # single quote) from `\\$'` (escaped backslash → REAL ANSI-C
            # string whose \' doesn't terminate — false ALLOW found in
            # review). Side effect: `\ #` no longer reads as
            # space-then-comment, matching bash (the # is mid-word).
            buf.append(ch + text[i + 1]); i += 2; continue
        if ch == "#" and (not buf or buf[-1] in " \t"):
            # Comment to end-of-line; the newline itself still splits below.
            while i < n and text[i] != "\n":
                i += 1
            continue
        if ch == "\n":
            segs.append("".join(buf)); buf = []; i += 1
            # Consume the bodies of heredocs opened on the line just
            # finished, in order. Quoted-delimiter bodies are dropped;
            # unquoted-delimiter bodies are emitted line-by-line as
            # standalone segments (conservative scan, no quote tracking).
            while pending:
                delim, strip_tabs, quoted = pending.pop(0)
                while i < n:
                    j = text.find("\n", i)
                    line = text[i:j] if j != -1 else text[i:]
                    i = j + 1 if j != -1 else n
                    if (line.lstrip("\t") if strip_tabs else line) == delim:
                        break
                    if not quoted:
                        # Split body lines at separators too: fed to a shell
                        # (`bash <<EOF`) the body EXECUTES, and judging only
                        # the line's START let `true; git commit` — and a
                        # safe `git -C <wt> add; git commit` — through
                        # (false ALLOW found in review). Still no quote
                        # tracking: body prose stays inert.
                        segs.extend(re.split(r"(?:&&|\|\||;|\|)", line))
            continue
        if ch == ";":
            segs.append("".join(buf)); buf = []; i += 1; continue
        if text[i:i + 2] in ("&&", "||"):
            segs.append("".join(buf)); buf = []; i += 2; continue
        if ch == "|":
            segs.append("".join(buf)); buf = []; i += 1; continue
        if text[i:i + 3] == "<<<":
            # <<< is a herestring, not a heredoc opener: the word after it
            # is an ordinary (possibly quoted) argument and the following
            # LINES are real commands. Skipping only the FIRST `<` let the
            # scanner re-match `<<'word'` one char later and drop those
            # lines as a phantom quoted heredoc body (false ALLOW found in
            # review). Consumed as a unit; the word after it goes through
            # normal quote tracking, which is exactly how bash reads it.
            buf.append("<<<"); i += 3; continue
        if text[i:i + 2] == "<<":
            # A backslash-quoted delimiter (<<\EOF) is quoted to bash exactly
            # like <<'EOF' — body literal, terminator EOF. Not matching it
            # left the body lines in the normal scan, where a body apostrophe
            # corrupted the quote tracker and swallowed the commands after
            # the terminator (false ALLOW).
            # The delimiter charset is deliberately wide (any word bash
            # would accept, stopping at shell metacharacters): limiting it
            # to \w left real openers like <<'E-O-F' unrecognized, and the
            # unrecognized body corrupted the quote tracker the same way
            # (false ALLOW found in review). Bash performs NO expansion on
            # the delimiter word, so `$`/backtick chars in it are literal.
            # Quoted delimiters may be EMPTY (<<'' — body ends at the first
            # empty line, a real heredoc to bash): hence * not + in the two
            # quoted arms. Leaving <<'' unrecognized let its body apostrophe
            # corrupt the quote tracker and swallow the post-terminator bare
            # git (false ALLOW found in review).
            hm = re.match(
                r"<<(-?)\s*(?:\\([^\s'\"\\;&|<>()]+)"
                r"|'([^'\n]*)'"
                r"|\"([^\"\n]*)\""
                r"|([^\s'\"\\;&|<>()]+))", text[i:])
            # Pure-digit unquoted words register as openers too: `cat <<2`
            # is a real heredoc, and skipping it (an earlier heuristic for
            # arithmetic left-shifts) let ITS body apostrophe corrupt the
            # quote tracker the same way (false ALLOW found in review). An
            # arithmetic operand ($((x<<2))) registering as a phantom opener
            # is safe: its "body" — every following line until a bare `2`
            # line, usually none — gets the conservative unquoted-body scan,
            # which errs deny-direction, never allow.
            if hm:
                # Empty quoted delims make `or`-chaining wrong ("" is falsy):
                # pick the first group that PARTICIPATED in the match.
                delim = next(g for g in hm.groups()[1:] if g is not None)
                quoted = hm.group(5) is None
                pending.append((delim, hm.group(1) == "-", quoted))
                buf.append(hm.group(0)); i += len(hm.group(0)); continue
        buf.append(ch); i += 1
    segs.append("".join(buf))
    return segs

segments = split_segments(cmd)

def _git_out(path, *args):
    try:
        r = subprocess.run(
            ["git", "-C", path, *args],
            capture_output=True, text=True, timeout=5,
        )
    except Exception:
        return None
    if r.returncode != 0:
        return None
    return r.stdout.strip()

def is_worktree_path(p: str) -> bool:
    # Normalise LEXICALLY before any test reads the text. A path like
    # .../.claude/worktrees/foo/../.. CONTAINS the marker while its effective
    # target is two levels up — the master worktree this guard exists to
    # protect — and the bare substring test below accepted it.
    # normpath, never realpath: the fast-path fixtures name directories that
    # do not exist on disk, so a filesystem-dependent resolve would change
    # what they test and make the outcome host-specific.
    p = os.path.normpath(os.path.expanduser(p.strip("'\"")))
    # Fast path: any path containing /<worktrees_dir>/ — covers both abs
    # and relative forms, no subprocess needed.
    if WT_MARK in p:
        return True
    # Slow path: a LINKED worktree living outside the repo root
    # (e.g. `git worktree add ../<name>`) is an explicit, non-master target
    # and must be allowed. Resolve the -C target: it must be inside a work
    # tree, and that work tree must NOT be the MAIN worktree of its
    # repository (the main worktree's top is the parent of the git common
    # dir — the protected master worktree; for any other repo, refusing its
    # main worktree keeps the same explicitness discipline). Anything unresolvable stays refused (fail-closed).
    # Accepted caveats: a main worktree created with --separate-git-dir and
    # a submodule checkout both resolve as "linked" here and would be
    # allowed.
    if not os.path.isdir(p):
        return False
    top = _git_out(p, "rev-parse", "--show-toplevel")
    if not top:
        return False
    common = _git_out(p, "rev-parse", "--path-format=absolute", "--git-common-dir")
    if common is None:
        # git < 2.31 fallback: relative output is relative to the -C dir.
        common = _git_out(p, "rev-parse", "--git-common-dir")
        if common is None:
            return False
        if not os.path.isabs(common):
            common = os.path.join(p, common)
    main_top = os.path.dirname(os.path.realpath(common))
    return os.path.realpath(top) != main_top

def unquote_word(word: str):
    # Resolve one shell word to the path bash would hand git, or None when
    # that cannot be known statically. Stripping quotes at the two ENDS of the
    # word left `foo/'..'` and `../'..'` intact: bash concatenates the pieces
    # into `foo/..`, while normpath read `'..'` as an ordinary directory name
    # and the worktree marker survived. shlex performs the same concatenation
    # bash does. A word carrying `$` or a backtick expands to a value this
    # hook cannot see — `-C <wt> -C $HOME` is absolute after expansion and
    # lands on master — so it is unresolvable, and the caller fails closed.
    if re.search(r"[$`]", word):
        return None
    try:
        parts = shlex.split(word)
    except ValueError:
        return None
    if len(parts) != 1:
        return None
    return os.path.expanduser(parts[0])

def override_ok(value: str, c_path: str) -> bool:
    # --git-dir / --work-tree values are resolved by git AFTER -C is applied, so
    # they are tested against the -C target, never against the hook's own cwd.
    # Checking the raw string made `--work-tree=.` mean whatever directory the
    # hook happened to run in: refused from the master checkout, allowed from a
    # linked worktree, and in both cases answering a question nobody asked.
    value = unquote_word(value)
    if value is None:
        return False
    resolved = os.path.normpath(os.path.join(c_path or ".", value))
    if is_worktree_path(resolved):
        return True
    # A linked worktree has no .git DIRECTORY: its .git is a file reading
    # `gitdir: <main>/.git/worktrees/<name>`, so the correct --git-dir for a
    # worktree lives under the MAIN repo's .git and carries no
    # worktrees_dir marker. Verified against a real `git worktree add`:
    # --git-dir=<main>/.git/worktrees/foo, --git-dir=.git and --work-tree=.
    # all commit into the worktree, so all three have to pass.
    return "/.git/worktrees/" in resolved

findings = []
for raw in segments:
    seg = raw.strip()
    if not seg:
        continue
    # Strip a leading env-var assignment if present (e.g.,
    # `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES git ...`).
    seg_stripped = re.sub(r"^([A-Z_][A-Z0-9_]*=\S+\s+)+", "", seg)
    # Find git invocations: `git` then optional global flags then a
    # subcommand. -C is one of the flags rather than a single optional slot,
    # because a SECOND -C used to land where the subcommand was expected: the
    # match failed and the segment was skipped, which is this guard's ALLOW
    # path. Same for the `=` forms of --git-dir / --work-tree, which
    # the space-only alternatives could not match.
    m = INVOCATION.match(seg_stripped)
    if not m:
        # FAIL CLOSED. The flag alternation is a hand-kept list, so every flag
        # git adds or we forgot used to be a silent hole: `git -P commit` and
        # `git --literal-pathspecs commit` both committed in master with the
        # hook staying quiet, and a quoted `-c` value containing a space made
        # the parser read the value's tail as the subcommand. An invocation we
        # cannot parse is refused instead, with one carve-out: `git` followed
        # only by flags (`git --version`, `git --help`) names no subcommand and
        # so can mutate nothing.
        if not re.match(r"git(\s|$)", seg_stripped):
            continue
        if not re.search(r"(?:^|\s)(?!-)\S", re.sub(r"^git\s*", "", seg_stripped)):
            continue
        findings.append({
            "segment": seg.strip(),
            "subcommand": "(unparsed)",
            "c_path": "(absent)",
            "reason": "could not parse the git invocation; use `git -C <worktree> <subcommand>` "
                      "with unquoted paths, or simplify the command",
        })
        continue
    sub = m.group(1) or ""
    if not sub:
        continue
    flags = seg_stripped[: m.start(1)]
    # git applies -C cumulatively and a later absolute -C wins outright —
    # exactly os.path.join's rule — so the effective target is the join of
    # every hop, not the first one. Each hop is unquoted and expanded BEFORE
    # the join: joining the raw text left the quotes mid-path, where the
    # end-only strip in is_worktree_path could not reach them, and `'..'` then
    # read as an ordinary directory name instead of a level up.
    c_path = ""
    unresolved = []
    for hop in re.findall(r"(?:^|\s)-C\s+(" + VALUE + r")", flags):
        clean = unquote_word(hop)
        if clean is None:
            # One hop the hook cannot resolve poisons the whole join: a later
            # absolute hop replaces everything before it, so an opaque hop can
            # point anywhere. Fail closed on the segment.
            unresolved.append(hop)
            c_path = ""
            break
        c_path = os.path.join(c_path, clean) if c_path else clean
    # --git-dir and --work-tree name the repository and the tree directly, so
    # one pointing at master defeats an otherwise well-formed -C.
    dir_overrides = re.findall(r"(?:^|\s)--(?:git-dir|work-tree)(?:\s+|=)(" + VALUE + r")", flags)
    if sub not in MUTATING:
        continue

    # Special-case branch/tag/worktree/stash: those are "MUTATING" only with
    # certain flags. The destructive-git guard already handles destructive
    # forms; here we accept their read-only forms (branch listing, tag
    # listing, etc.) by checking the remaining args.
    rest = seg_stripped[m.end():]
    if sub == "branch":
        # Mutating forms: `-d`, `-D`, `--delete`, `-m`, `--move`, `-c`, `--copy`,
        # `--unset-upstream`, `-u`/`--set-upstream-to`, or just a name (creates).
        # Listing is `branch` (no extra args) or `--list` / `-a` / `-r` / `--show-current`.
        if re.search(r"(^|\s)(-d|-D|--delete|-m|--move|-M|-c|--copy|-C|-u|--set-upstream-to)(\s|=|$)", rest):
            pass  # destructive-git handles -D; -d is benign in our context — allow
        elif re.search(r"^\s*(--list|-l|-a|--all|-r|--remotes|--show-current|--contains|--no-contains|--merged|--no-merged|--column|--sort|--format)?\s*$", rest):
            continue  # listing, allow
        else:
            # Creating a branch from current HEAD ('git branch new-name') —
            # treat as mutating because it derives from cwd HEAD.
            pass
    elif sub == "tag":
        # `git tag` (list) is read-only; `git tag <name>` (create) mutates refs.
        # Listing-form: bare `tag`, OR rest begins with a listing flag.
        if rest.strip() == "" or re.match(r"^\s*(--list|-l|--contains|--no-contains|--merged|--no-merged|-n|--column|--sort)(\s|=|$)", rest):
            continue
    elif sub == "worktree":
        # `worktree add/list/remove/move/repair/lock/unlock/prune` — none
        # of these affect master HEAD or commit history. Allow.
        continue
    elif sub == "stash":
        # destructive-git guard handles all mutating stash forms. Allow here.
        continue
    elif sub == "notes":
        # Listing forms ok; mutating refs/notes/* falls through. Skip the
        # fine-grained split — refuse the mutating forms with the same
        # bare-cwd test below.
        if re.search(r"^\s*(list|show)?\s*$", rest):
            continue

    # At this point sub is a mutating op. Require -C with a worktree path, and
    # no repo/tree override aiming somewhere else.
    bad_overrides = [d for d in dir_overrides if not override_ok(d, c_path)]
    if c_path and is_worktree_path(c_path) and not bad_overrides:
        continue
    # Say which half failed. A refusal caused by --git-dir/--work-tree used to
    # print "no -C worktree path" with a perfectly good -C on the line, sending
    # the reader to add a flag they already had.
    if unresolved:
        reason = ("-C target cannot be resolved statically, use a literal path: "
                  + ", ".join(unresolved))
    elif bad_overrides:
        reason = ("--git-dir/--work-tree resolves outside the worktree: "
                  + ", ".join(bad_overrides))
    else:
        reason = "no -C worktree path"
    findings.append({
        "segment": seg.strip(),
        "subcommand": sub,
        "c_path": c_path or "(absent)",
        "reason": reason,
    })

print(json.dumps({"findings": findings}))
PY

ANALYSIS="$(CMD_INPUT="$CMD" WT_DIR="$WT_DIR" python3 -c "$PY_ANALYZER")"

FINDINGS_COUNT="$(printf '%s' "$ANALYSIS" | jq -r '.findings | length')"
if [ "$FINDINGS_COUNT" -eq 0 ]; then
  exit 0
fi

# Build a refusal reason listing the offending segments.
SEGMENTS_DESC="$(printf '%s' "$ANALYSIS" | jq -r '.findings | map("  - git " + .subcommand + " (" + (.reason // "no -C worktree path") + "; segment: " + .segment + ")") | join("\n")')"

read -r -d '' REASON <<REASONEOF || true
Refused: mutating git op without \`git -C <worktree-path>\`.

Offending segment(s):
${SEGMENTS_DESC}

The Bash tool's cwd does not persist across separate Bash tool calls: each
call starts in the session's default directory, which is the master
worktree. A \`cd\` works within one call's && chain only. So
\`git add\`/\`commit\`/\`push\` without an explicit \`-C\` silently target
master and sweep up whatever other sessions left there.

Required form:

  git -C <repo>/${WT_DIR}/<name> add <paths>
  git -C <repo>/${WT_DIR}/<name> commit -s -F <msgfile>
  git -C <repo>/${WT_DIR}/<name> push -u origin <branch>

A LINKED worktree outside the repo (\`git worktree add <path>\`) is also
accepted as a \`-C\` target; only the main worktree and non-worktree paths
are refused.

For the rare case of deliberately mutating master (cleaning up after
another session, under operator direction), prefix the command:

  AGENT_ALLOW_MASTER_GIT_MUTATE=1 git <subcommand> ...

Confirm with the operator before using it on a tree carrying uncommitted
work.
REASONEOF

aw_deny "$REASON"
exit 0
