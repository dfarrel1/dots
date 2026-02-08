# Highlights

The best stuff buried in these dotfiles. If you only remember a few commands, make it these.

---

## Navigation

| Command | What it does |
|---------|-------------|
| `g2 <term>` | Fuzzy-match a subdirectory name and cd into it |
| `gd <term>` | Same thing but recursive — searches the whole tree below you |
| `gf <term>` | Recursive fuzzy file finder |
| `rv <term>` | Revisit — fuzzy search your directory stack (everywhere you've been) |
| `b [N]` | Go back N directories in the stack (default 1) |
| `ld` | List your full directory stack with indices |
| `hg <term>` | Grep your shell history with highlighted matches |
| `mkd <dir>` | Create a directory and cd into it in one shot |

**Tip:** `cd` is wrapped with `pushd`, so every directory you visit is saved. Use `rv` to jump back to anywhere you've been this session.

---

## Git

| Command | What it does |
|---------|-------------|
| `clone <url>` | Clone into your GOPATH tree with automatic SSH alias resolution |
| `bro` | Open the current repo in Chrome on the hosting site |
| `or <name>` | Jump to a repo by name under your GOPATH |
| `base` | cd to the root of the current repo |
| `repo_info` | Print domain/org/repo/branch breakdown of your current path |
| `glog` | Pretty git log graph with colors |
| `gclu` | Safely remove untracked files (interactive confirmation) |
| `gclb` | Clean up local branches that are gone from remote |
| `newghpattern <url>` | Add a new GitHub org with SSH identity mapping — handles gitconfig + aliases |
| `gadd "msg"` | Git add all + commit + push in one command |

**Tip:** `newghpattern` is the one to remember when onboarding to a new client or org. It wires up SSH keys, URL rewrites, and conditional git identity in one step.

---

## Docker / Kubernetes

| Command | What it does |
|---------|-------------|
| `dbash [filter]` | Fuzzy-select a running container and drop into bash |
| `dsh [filter]` | Same but with sh (for alpine/minimal containers) |
| `dlogs [filter]` | Fuzzy-select a container and tail its logs |
| `cld` | Nuclear option — remove all containers, images, and prune |
| `restartdocker` | Full Docker restart cycle (stop all, quit app, relaunch) |
| `k` | kubectl shorthand |
| `kex` | kubectl exec -it |
| `klo` | kubectl logs -f |

---

## AWS / 1Password

| Command | What it does |
|---------|-------------|
| `mfa [name]` | Get a TOTP code from 1Password and copy it to clipboard |
| `awskeys` | Export AWS access keys from 1Password into your environment |
| `newawsprofile` | Create an aws-vault profile directly from a 1Password secret |
| `1p` | Start a 1Password CLI session |

---

## Productivity

| Command | What it does |
|---------|-------------|
| `c.` | Open the current repo in VS Code |
| `ep` | Edit your profile scripts in VS Code |
| `close <term>` | Search open ports and kill a matching process |
| `source_env <file>` | Source a .env file, exporting all variables |
| `pb` | Copy the last command you ran to clipboard |
| `awake` / `decaf` | Prevent / allow sleep |
| `ports` | List listening and established connections |
| `chp` | Pick a shell prompt theme (zoidberg, octopus, koala, etc.) |
| `splasher` | Random ASCII art splash |

---

## Patterns Worth Knowing

**Fuzzy selection is everywhere.** Functions like `g2`, `rv`, `dbash`, `clone`, `mfa`, and `venv` all use the same `get_choice` engine — type a partial match to filter, then pick by number or press Enter for the first result.

**SSH identity is automatic.** Once you run `newghpattern`, every `git clone` and `git push` to that org uses the right SSH key and commit email. No manual switching.

**Your config is backed up.** Run `./xtra/private/push_secrets_to_1pass.sh` to snapshot your SSH config, git identity mappings, shell configs, and GPG preferences to 1Password. Restore on a new machine with `./xtra/newcomp.sh`.

---

_See the full reference in [ALLTABLES.md](./docs/ALLTABLES.md). Regenerate with `make docs`._
