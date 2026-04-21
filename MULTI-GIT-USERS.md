# Multi-Identity GitHub Workflow (SSH + GPG)

This document describes a **deterministic, reproducible pattern** for working with **multiple GitHub identities** on a single machine while ensuring:

- The **correct SSH key** is used for each repository
- The **correct Git author identity** is applied automatically
- The **correct GPG signing key** is used for commits
- The setup scales cleanly to:
  - multiple personal accounts
  - GitHub organizations
  - third-party repositories you contribute to
- CLI and GUI Git clients (e.g. SourceTree) behave consistently

The design intentionally avoids per-repository manual configuration and instead relies on **directory structure + Git conditional includes + SSH host aliasing**.

---

## Core Design Principles

1. **Identity is determined by repository location**, not by memory or manual flags
2. **SSH transport identity and Git author identity are decoupled**
3. **Everything is explicit, inspectable, and debuggable**
4. **No repository-local identity hacks**
5. **Scales linearly with additional identities**

---

## High-Level Architecture

```
┌──────────────────────────┐
│ Working Directory Path   │
│ (gitdir:~/src/...)       │
└────────────┬─────────────┘
             ↓
┌──────────────────────────┐
│ includeIf in .gitconfig  │
│ selects identity file    │
└────────────┬─────────────┘
             ↓
┌──────────────────────────┐
│ Identity-specific        │
│ gitconfig fragment       │
│ (name, email, GPG key)   │
└──────────────────────────┘

┌──────────────────────────┐
│ Git remote URL rewrite   │
│ (insteadOf rules)        │
└────────────┬─────────────┘
             ↓
┌──────────────────────────┐
│ SSH Host Alias           │
│ (gh-<identity>)          │
└────────────┬─────────────┘
             ↓
┌──────────────────────────┐
│ SSH key selection        │
│ via ~/.ssh/config        │
└──────────────────────────┘
```

---

## Step 1: Directory Layout (The Control Plane)

All repositories are cloned into a **predictable directory hierarchy**:

```
~/src/
  github.com/
    identity-a/
      repo1/
      repo2/
    identity-b/
      repo3/
    org-x/
      repo4/
    org-y/
      repo5/
```

**Rule:**  
The filesystem path determines the Git identity.

This removes the need to remember which account is “active.”

---

## Step 2: SSH Host Aliases (Transport Identity)

Instead of using `github.com` directly, define **logical SSH hosts**.

### `~/.ssh/config`

```ssh
Host gh-*
  HostName github.com
  User git
  IdentitiesOnly yes
  AddKeysToAgent yes

Host gh-identity-a
  IdentityFile ~/.ssh/id_rsa_identity_a

Host gh-identity-b
  IdentityFile ~/.ssh/id_rsa_identity_b
```

### Why This Worksorks

- `gh-*` provides shared defaults
- Each logical host maps to exactly one SSH key
- `IdentitiesOnly yes` prevents key-guessing
- The host alias encodes intent explicitly

---

## Step 3: Git URL Rewriting (Automatic SSH Routing)
Git transparently rewrites repository URLs to the correct SSH host alias.

### `~/.gitconfig.d/github-aliases.ini`

```ini
[url "ssh://git@gh-identity-a/identity-a/"]
    insteadOf = https://github.com/identity-a/
    insteadOf = git@github.com:identity-a/

[url "ssh://git@gh-identity-b/identity-b/"]
    insteadOf = https://github.com/identity-b/
    insteadOf = git@github.com:identity-b/
```

### Resultsult

Any of the following:

```
https://github.com/identity-a/repo.git
git@github.com:identity-a/repo.git
```

Is rewritten internally to:

```
ssh://git@gh-identity-a/identity-a/repo.git
```

Which enforces the correct SSH key automatically.

---

## Step 4: Conditional Git Identities (Author + GPG)

Git selects the correct author identity based on repository location.

### Global `~/.gitconfig`

```ini
[user]
    name = default-user
    email = default@example.com

[commit]
    gpgsign = true

[include]
    path = ~/.gitconfig.d/github-aliases.ini

[includeIf "gitdir:~/src/github.com/identity-a/"]
    path = ~/.gitconfig.d/identity-a.ini

[includeIf "gitdir:~/src/github.com/identity-b/"]
    path = ~/.gitconfig.d/identity-b.ini
```

### Identity-Specific Fragments

```ini
# ~/.gitconfig.d/identity-a.ini
[user]
    name = identity-a
    email = identity-a@example.com
    signingkey = GPG_KEY_ID_A
```

```ini
# ~/.gitconfig.d/identity-b.ini
[user]
    name = identity-b
    email = identity-b@example.com
    signingkey = GPG_KEY_ID_B
```

### Notes
The most specific include wins

Commits are always GPG-signed

Works seamlessly with GUI tools

Step 5: Organizations & Third-Party Repositories
Organizations are treated as identity routing domains.

### Example:

```
~/src/github.com/org-x/   → identity-a
~/src/github.com/org-y/   → identity-b
```

```ini
[includeIf "gitdir:~/src/github.com/org-x/"]
    path = ~/.gitconfig.d/identity-a.ini

[includeIf "gitdir:~/src/github.com/org-y/"]
    path = ~/.gitconfig.d/identity-b.ini
```

### This supports:rts:

- Multiple organizations per identity
- Contributing to repositories you do not own
- Correct attribution without manual steps

---

## Step 6: Cloning Repositories (Correct by Construction)
To clone a repository:

```bash
git clone https://github.com/identity-a/repo.git
```

Git will automatically:

1. Rewrite the URL
2. Select the SSH key
3. Select the Git identity
4. Select the GPG signing key

No flags, no per-repo configuration.

---

## Debugging & Verification

### Verify active Git identity

```bash
git config user.name
git config user.email
git config user.signingkey
```

### Verify SSH key selection

```bash
ssh -T gh-identity-a
```

### Verify rewritten remotes

```bash
git remote -v
```

---

## Step 7: The `gh` CLI gap (manual check required)

The mechanisms above govern Git itself and SSH transport. The **GitHub CLI (`gh`)** does not participate in any of them. It keeps a single globally-active account in the OS keyring and consults neither `includeIf`, SSH host aliases, nor the current working directory.

That means `gh api`, `gh pr comment`, `gh issue create`, `gh release`, etc. are attributed to whichever account last ran `gh auth switch` — regardless of which repo you are in. This has caused PR review comments and issue replies to be posted from the wrong identity.

No wrapper or automation is installed for this — deliberately. Any `gh` interception adds latency, edge cases, and a new failure mode to a daily-driver tool. The check stays manual and explicit.

### Before any `gh` action in a fork or external-org repo

```bash
gh auth status                         # find active account
gh auth switch -u <account-from-path>  # change if needed
```

The "account-from-path" is the `{account}` segment of `~/src/github.com/{account}/...` — the same segment `includeIf` keys on for Git. For external-org paths, look up the owning identity in `~/.gitconfig` (the `[includeIf "gitdir:~/src/github.com/{org}/"]` block names the `identity-<name>.ini` file).

Both accounts must already be in the keyring (`gh auth login --hostname github.com --git-protocol ssh` once per identity).

---

## Why This Pattern Is Robust

- No hidden or mutable state
- No reliance on credential helpers
- No per-repository identity footguns
- Survives rebases, amend, force-pushes
- Deterministic and self-documenting

This is not a workaround — it is a disciplined composition of Git and SSH as designed.

---

## Mental Model (TL;DR)

- **Path** selects Git identity (name / email / GPG key) via `includeIf`.
- **URL** selects SSH key via host alias.
- **`gh` CLI is out-of-band** — verify the active account matches the path segment before posting.

Once these invariants hold, identity errors simply stop happening.