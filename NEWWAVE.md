# New Wave — Modern CLI Tools

These are modern replacements and upgrades for standard Unix tools, integrated into the dotfiles via `profile/newwave.sh`. Each tool is guarded — if it's not installed, the shell skips it silently.

**Install everything at once:**

```bash
install_newwave
```

Or manually:

```bash
brew install zoxide fzf atuin bat eza git-delta fd ripgrep
```

---

## zoxide — smart `cd`

**What it replaces:** `z.sh` (already in your brew_sources), and partially `goto`/`go_deep`

zoxide tracks every directory you visit and ranks them by *frecency* (frequency + recency). Instead of typing full paths, you type a partial name and zoxide jumps to the best match.

```bash
z foo          # cd to the highest-ranked directory matching "foo"
z foo bar      # match must contain both "foo" and "bar"
zi             # interactive picker — fuzzy search all ranked directories
```

**Why it's better than `z.sh`:** Rust-based (instant), better ranking algorithm, and `zi` gives you an interactive fuzzy list instead of silently guessing. Pairs beautifully with fzf.

**Your existing tools that still add value alongside zoxide:**
- `rv` (revisit) — searches your *session* stack, not frecency history. Different use case.
- `g2` (goto) — searches *only immediate subdirectories*. Useful when you want to stay local.
- `b` (back) — stack-based back navigation. zoxide doesn't replace this.

---

## fzf — fuzzy finder for everything

**What it replaces:** Nothing directly — it *enhances* everything.

fzf is a general-purpose fuzzy finder that plugs into your shell as keybindings and into any command via pipes.

### Keybindings (automatic after install)

| Keybinding | What it does |
|------------|-------------|
| `Ctrl-R` | Fuzzy search command history (replaces default reverse search) |
| `Ctrl-T` | Fuzzy file finder — inserts selected path at cursor |
| `Alt-C` | Fuzzy `cd` — pick a subdirectory and jump into it |

### Piping

Pipe any list into fzf for interactive selection:

```bash
docker ps | fzf                    # pick a container
git branch | fzf                   # pick a branch
brew list | fzf                    # pick a formula
cat ~/.ssh/config | fzf            # search SSH config
```

### Custom functions added by newwave.sh

| Command | What it does |
|---------|-------------|
| `fbr` | Fuzzy-select a git branch and switch to it |
| `flog` | Fuzzy-search git log, preview commits |
| `fkill` | Fuzzy-select and kill a process |
| `fpreview` | Browse files with bat preview |

**Why you should use it:** fzf is the single most impactful tool here. Your `get_choice` engine is smart, but fzf gives you real-time incremental fuzzy matching with preview panes, multi-select, and keybindings — all for free. Functions like `dbash`, `rv`, `mfa`, and `venv` could eventually be rewritten to pipe through fzf for an even better experience.

---

## atuin — shell history with context

**What it replaces:** `Ctrl-R`, `hg` (history grep), `history` command

atuin stores every command you run in a local SQLite database along with:
- The directory you were in
- The exit code
- How long it took
- The hostname

This means you can search history *by directory*, filter to only successful commands, or find "that long command I ran last week in the project root."

```bash
# Just press Ctrl-R — atuin takes over with a full-screen fuzzy search
# Or use the CLI directly:
atuin search "docker"              # search all history
atuin search --cwd . "make"        # search history for THIS directory only
atuin search --exit 0 "deploy"     # only successful commands
atuin stats                        # usage statistics
```

**Optional sync:** atuin can encrypt and sync your history across machines. Fits well with your 1Password cross-machine philosophy — though the history sync uses atuin's own server (or self-hosted). You can skip sync and just use it locally.

**Setup after install:**

```bash
atuin init bash                    # already handled by newwave.sh
atuin import auto                  # one-time: import existing bash history
```

---

## bat — `cat` with syntax highlighting

**What it replaces:** `cat`, and improves `man` pages

bat is a drop-in `cat` replacement with automatic syntax highlighting, line numbers, and git change markers in the margin.

```bash
cat file.py                        # aliased to bat — syntax highlighted
catp file.py                       # bat with paging (like less, but pretty)
man git-rebase                     # man pages render through bat automatically
```

**Why bother:** Every time you `cat` a config file, script, or log, you get instant syntax highlighting. The git gutter shows which lines changed. Small upgrade, but you use `cat` constantly.

---

## eza — modern `ls`

**What it replaces:** `ls`, `ll`, `la`

eza gives you color-coded output with git status per file, a proper tree view, and sane defaults.

```bash
ls                                 # aliased to eza — colorized with file type icons
ll                                 # eza -la --git — long listing with git status
lt                                 # eza --tree --level=2 — tree view
lt3                                # 3-level tree
llt                                # long listing + tree combined
```

**The git integration is the killer feature:** Each file shows its git status (modified, staged, untracked) right in the `ls` output. You see what changed without running `git status`.

---

## delta — better git diffs

**What it replaces:** The default git diff pager

delta adds syntax highlighting, line numbers, and side-by-side view to every `git diff`, `git show`, `git log -p`, and `git stash show`. Once configured, it works automatically — no aliases needed.

**Setup (one-time, after install):**

Add to your `~/.gitconfig`:

```ini
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    side-by-side = true
    line-numbers = true
```

**Why it matters:** You read diffs constantly. delta makes them dramatically easier to parse, especially for large changes. Side-by-side view alone is worth the install.

---

## fd — modern `find`

**What it replaces:** `find`, and can speed up `gf` (go_find)

fd is a fast, user-friendly alternative to `find`. It respects `.gitignore` by default, uses regex patterns, and has colorized output.

```bash
f "\.sh$"                          # find all .sh files (aliased from fd)
fd --type d config                 # find directories named "config"
fd --hidden --no-ignore "\.env"    # include hidden and gitignored files
fd -e json                         # find all .json files
```

**Why it's better than `find`:** Sane defaults (no `-name`, `-type f` boilerplate), 5-10x faster on large trees, and respects `.gitignore` so you don't wade through `node_modules`. Also powers fzf's `Ctrl-T` and `Alt-C` when both are installed.

---

## ripgrep — fastest grep

**What it replaces:** `grep -r`, `egrep`, and partially `hg`

ripgrep (`rg`) is the fastest code searcher available. Recursive by default, respects `.gitignore`, and has excellent output formatting.

```bash
rg "TODO"                          # search all files recursively
rg "TODO" --type sh                # only in .sh files
rg -i "fixme" src/                 # case-insensitive in src/
rgs "pattern"                      # aliased: rg with smart-case + pager
```

**Why over grep:** It's ~10x faster than `grep -r` on large repos, skips binary files and `.git` automatically, and the output format (with filenames, line numbers, color) is immediately useful.

---

## Tool Synergy

These tools are designed to work together:

| Combination | What happens |
|------------|-------------|
| fzf + fd | `Ctrl-T` and `Alt-C` use fd for blazing fast file/directory search |
| fzf + bat | `fpreview` shows syntax-highlighted file previews in the picker |
| fzf + rg | Pipe `rg` output into fzf for interactive grep result selection |
| fzf + zoxide | `zi` uses fzf for interactive directory jumping |
| fzf + git | `fbr` and `flog` give you interactive branch/commit selection |
| bat + delta | Both use the same syntax highlighting engine — consistent colors |
| bat + man | Man pages automatically render through bat |

---

## Quick Reference

| Command | Tool | What it does |
|---------|------|-------------|
| `z <term>` | zoxide | Jump to best-matching directory |
| `zi` | zoxide | Interactive directory picker |
| `Ctrl-R` | fzf/atuin | Fuzzy history search |
| `Ctrl-T` | fzf | Fuzzy file finder at cursor |
| `Alt-C` | fzf | Fuzzy cd into subdirectory |
| `fbr` | fzf+git | Fuzzy branch switcher |
| `flog` | fzf+git | Fuzzy commit browser |
| `fkill` | fzf | Fuzzy process killer |
| `fpreview` | fzf+bat | Browse files with preview |
| `cat` | bat | Syntax-highlighted cat |
| `ll` | eza | Long listing with git status |
| `lt` | eza | Tree view |
| `f <pattern>` | fd | Fast file finder |
| `rgs <pattern>` | ripgrep | Recursive grep with pager |
| `install_newwave` | brew | Install all tools at once |

---

_These tools are sourced from `profile/newwave.sh`. Each is guarded — if not installed, it's silently skipped. Run `install_newwave` to get everything set up._
