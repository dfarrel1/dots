# Navigation — How to Move Around Like You Mean It

This guide covers every navigation function, alias, and pattern in these dotfiles. The navigation system is built on two ideas: **every directory you visit is remembered**, and **fuzzy matching gets you back to it fast**.

---

## The Core Idea: `cd` is `pushd`

The single most important thing to understand:

```bash
alias cd='pushd . >> /dev/null;cd'
```

Every `cd` you run silently pushes the previous directory onto a stack. This means your entire session history is preserved — you can jump back to anywhere you've been.

This is **always active** and requires no effort. Just use `cd` normally and the stack builds itself.

---

## The Directory Stack

| Command | What it does |
|---------|-------------|
| `ld` | List your full directory stack with numbered indices |
| `b` | Go back one directory in the stack |
| `b 3` | Go back three directories |
| `rv` | Fuzzy-search the entire stack and jump to a match |
| `rv proj` | Fuzzy-search the stack, pre-filtered to entries matching "proj" |

### Example workflow

```bash
cd ~/src/github.com/myorg/frontend    # stack: [0] frontend
cd ~/src/github.com/myorg/backend     # stack: [0] backend [1] frontend
cd /etc/nginx                         # stack: [0] nginx [1] backend [2] frontend
cd ~/Documents/notes                  # stack: [0] notes [1] nginx [2] backend [3] frontend

ld                                    # see the full stack with numbers
b                                     # back to /etc/nginx
b 2                                   # back to ~/src/.../frontend

rv back                               # fuzzy search → finds "backend", jumps there
```

**Tip:** The stack persists for the lifetime of your shell session. Open a terminal in the morning, work across 20 directories, and `rv` can take you back to any of them in the afternoon.

---

## Fuzzy Navigation Functions

All of these use the `get_choice` fuzzy selector. When there are multiple matches, you see a numbered list. You can:
- Type a **number** and press Enter to pick that item
- Type **more letters** to filter the list down further
- Press **Enter** with no input to pick the first match
- Type **q** to cancel

### `g2` / `goto` — search immediate subdirectories

```bash
g2 src        # list subdirectories matching "src", pick one, cd into it
g2            # list ALL subdirectories, pick one
```

Best for: Quick lateral moves within a project. You know roughly where you're going and it's one level down.

### `gd` / `go_deep` — recursive directory search

```bash
gd components    # find all directories below you matching "components"
gd test          # find every "test" directory in the tree
```

Best for: Diving deep into a project when you know the directory name but not the path. Searches the entire tree below your current location.

### `gf` / `go_find` — recursive file search

```bash
gf config.yaml   # find all files matching "config.yaml" below you
gf readme         # find all readmes in the tree
```

Best for: Finding a file when you know (part of) its name but not where it lives.

### `rv` / `revisit` — search your history

```bash
rv               # show the full directory stack, pick one
rv api           # filter to stack entries matching "api"
```

Best for: Jumping back to somewhere you've already been this session. The stack grows automatically from every `cd`.

---

## Quick Movement

| Command | What it does |
|---------|-------------|
| `..` | `cd ..` |
| `...` | `cd ../..` |
| `....` | `cd ../../..` |
| `.....` | `cd ../../../..` |
| `.3` | `cd ../../../` |
| `.4` | `cd ../../../../` |
| `.5` | `cd ../../../../..` |
| `home` | `cd ~` |
| `b` | Go back one in the stack (`popd`) |
| `b N` | Go back N entries in the stack |

---

## Repo-Aware Navigation

These live in `git.sh` but are essential to the navigation workflow:

| Command | What it does |
|---------|-------------|
| `base` | `cd` to the root of the current git repo |
| `or <name>` | Jump to a repo by name under your GOPATH |
| `clone <url>` | Clone into the GOPATH directory tree and cd into it |

### `or` — open repo

```bash
or dots          # jump to ~/src/github.com/.../dots (fuzzy matched)
or front         # jump to the first repo matching "front"
```

This is your cross-project teleporter. It searches your entire `$GOPATH/src` tree for repos matching the term.

### `base` — repo root

```bash
# you're in ~/src/github.com/myorg/app/src/components/Button/
base
# now in ~/src/github.com/myorg/app/
```

Always takes you to the root of the current git repo. Essential when you've been `gd`-ing deep into a tree.

---

## Utility

| Command | What it does |
|---------|-------------|
| `mkd <name>` | Create a directory and cd into it |
| `cdf` | cd to whatever the frontmost Finder window is looking at |
| `cls` | Open a new Terminal tab and close the current one (fresh start) |
| `newtab` | Open a new Terminal tab |
| `newtab "cmd"` | Open a new tab and run a command in it |

---

## History Search

| Command | What it does |
|---------|-------------|
| `hg <term>` | Grep your command history with highlighted matches |
| `h` | Full history |
| `h1` | Last 10 commands |
| `h2` | Last 20 commands |
| `h3` | Last 30 commands |

**With atuin installed** (see [NEWWAVE.md](./NEWWAVE.md)): `Ctrl-R` becomes a full-screen fuzzy history search with directory context, exit codes, and timing.

---

## Modern Upgrades (newwave.sh)

If you install the [modern tools](./NEWWAVE.md), you get additional navigation powers:

| Command | Tool | What it does |
|---------|------|-------------|
| `z <term>` | zoxide | Jump to frecency-ranked directory (learns your habits) |
| `zi` | zoxide | Interactive fuzzy directory picker from frecency history |
| `Ctrl-T` | fzf | Insert a file path at cursor via fuzzy search |
| `Alt-C` | fzf | Fuzzy cd into a subdirectory |
| `f <pattern>` | fd | Fast file finder (respects .gitignore) |

These complement rather than replace the existing tools:

| Situation | Best tool |
|-----------|-----------|
| Jump to a frequently-used directory by partial name | `z` (zoxide) |
| Jump to a directory you visited *this session* | `rv` (revisit) |
| Browse immediate subdirectories | `g2` (goto) |
| Find a deeply nested directory by name | `gd` (go_deep) |
| Get back to the repo root | `base` |
| Jump to a different repo entirely | `or` |
| Go back to where you just were | `b` |

---

## Patterns to Build Into Muscle Memory

1. **`g2` for local, `gd` for deep, `or` for cross-repo.** Three levels of navigation scope.

2. **`rv` is your session memory.** You don't need to remember paths — just `rv` and type a fragment.

3. **`base` before `g2`/`gd`.** When you're deep in a tree, `base` resets you to the repo root, then `g2` or `gd` to navigate from there.

4. **`b` is undo for `cd`.** Made a wrong turn? `b` takes you back. `b 3` takes you back three turns.

5. **The stack is free.** You don't need to do anything special — every `cd` saves your position. Use `ld` to see where you've been.

---

_Navigation functions live in [profile/navigation.sh](./profile/navigation.sh). Repo navigation in [profile/git.sh](./profile/git.sh). Modern tools in [profile/newwave.sh](./profile/newwave.sh)._
