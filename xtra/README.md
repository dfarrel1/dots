# Xtra: Workstation Bootstrap (macOS & Linux)

This directory contains the automation, configuration, and documentation for setting up a development machine. It uses a **"Zero Trust" Bootstrap Architecture** to separate public configuration (Brewfiles, app installers) from private identity plumbing.

## 🔐 Architecture Overview

To avoid checking secrets or sensitive logic into public version control, this repo uses a "Split-Brain" approach:

1.  **Public Layer (`newcomp.sh`)**: A lightweight, cross-platform orchestrator. It detects your OS (Mac vs. Linux), installs base dependencies (`brew` or `apt`), and acts as a secure bridge.
2.  **Private Layer (Stored in 1Password)**:
    * **Logic:** Private scripts to restore configuration.
    * **Data:** A "Configuration Bundle" containing your Git aliases, SSH config, and GPG agent settings.

When `newcomp.sh` runs, it authenticates with 1Password, downloads the configuration plumbing, establishes the correct system settings (Keychain vs Libsecret), and performs a **Gap Analysis** to tell you which private keys are missing.

## ⚠️ Important Notice

**WARNING:** The [newcomp.sh](newcomp.sh) script and surrounding bootstrap logic have been recently reengineered for improved security and functionality patterns. However, **this updated version has not yet been tested on a new computer setup**. While the architecture is sound, you may encounter unexpected issues during initial bootstrap. Please proceed with caution and be prepared to troubleshoot or fall back to manual configuration if needed.

## 🚀 Quick Start (New Machine)

1.  **Prerequisites**:
    * **macOS:** Ensure Xcode Command Line Tools are installed: `xcode-select --install`
    * **Linux:** Ensure basic tools are present: `sudo apt install curl git`
    * Have your **1Password Service Account Token** ready.

2.  **Run the Bootstrap**:
    ```bash
    cd xtra
    ./newcomp.sh
    ```

    * **Phase 1:** OS Detection & Dependency Install (Homebrew or Apt).
    * **Phase 2:** 1Password Authentication.
    * **Phase 3:** Restores **Configuration Plumbing** (SSH Config, Git Aliases, GPG Agent).
    * **Phase 4 (Audit):** Scans your config and tells you which SSH Keys to manually download from the Vault.

## 🐙 Git Multi-Identity Workflow

This machine handles multiple GitHub identities (Personal, Work, Client A, Client B) simultaneously without mixing SSH keys or commit emails.

### 1. The Strategy
We use **SSH Protocol Switching** and **Conditional Includes** to automate identity management.
* **No HTTPS:** All git traffic is automatically rewritten to SSH to utilize specific keys.
* **Directory Scoped:** The system detects which folder you are in (e.g., `~/src/github.com/client-name/`) and automatically swaps your `user.email` and `signingkey`.

### 2. Adding a New Organization (`newghpattern`)
When you join a new GitHub Organization or Client, do **not** edit your Git config manually. Use the helper tool included in `xtra/utils/git_helpers.sh`.

```bash
# 1. Run the tool with the new org URL
newghpattern [https://github.com/new-client-org/](https://github.com/new-client-org/)

# 2. Select the SSH Host (Key) to use
# > 1) gh-work
# > 2) gh-personal

# 3. Select the Identity Config (Email/GPG) to link
# > 1) identity-work.ini
# > 2) identity-personal.ini

# 4. Done! You can now clone normally:
git clone [https://github.com/new-client-org/repo.git](https://github.com/new-client-org/repo.git)
```

This command will safely update your `~/.gitconfig` and `~/.gitconfig.d/github-aliases.ini`.

### 3. Persistence
Your Global Git Config and the `~/.gitconfig.d/` folder are included in the **Configuration Bundle**. If you add a new pattern, remember to run the private push script to back up the new *mappings*.

## 🛠 Maintenance & Updates

### Updating the Config Bundle (`push`)
* **Script:** `xtra/private/push_secrets_to_1pass.sh` (Ignored by Git)
* **Usage:** Run this manually when you add new Git organizations, change SSH hosts, or modify global settings.
* **Function:** It bundles your **Configuration Only** (no private keys) and uploads it to 1Password.

### Updating the Restore Logic (`restore`)
* **Script:** `xtra/private/restore_secrets_from_1p.sh` (Ignored by Git)
* **Critical:** If you modify this script, you **must update the Document in 1Password** (`sys_script_restore`) so that `newcomp.sh` downloads the new version on fresh machines.

---

## 📂 Directory Guide

* **`newcomp.sh`**: The master entry point. Safe to commit.
* **`Brewfile`**: Defines all GUI apps (Casks) and CLI tools to install (macOS only).
* **`private/`**: (Git Ignored) Workspace for the sensitive maintenance scripts.
* **`utils/`**:
    * `git_helpers.sh`: Contains `newghpattern` for managing Git identities.
* **`ssh/`**: Scripts for creating new keys (`create.sh`) and config templates.

---

## 💻 Configuration Reference

### Cross-Platform Notes
The system attempts to be agnostic, but some manual tweaks may be required depending on your OS.

* **SSH Config:** We use `IgnoreUnknown UseKeychain` to allow the same config file to work on both macOS (Keychain) and Linux (standard agent).
* **Git Credentials:** The bootstrap automatically configures `osxkeychain` on Mac and `libsecret` (or cache) on Linux.

### MacOS Specifics
**Show Hidden Files:**
```bash
defaults write com.apple.Finder AppleShowAllFiles true
killall Finder
```

**Key Repeat / Cursor Speed:**
* Manually set Key Repeat to **Fast** and Delay Until Repeat to **Short**.
* Manually set Cursor Speed to **MAX**.

### Shell Management (ZSH vs Bash)
The scripts assume a standard Bash environment. If you need to switch from the default ZSH:
```bash
chsh -s $(which bash)
```

### IDEs & Editors
* **VSCode:** Install extensions and sync settings using the guide in `xtra/IDEs/vscode-settings.md`.
* **SourceTree (Mac):** Requires manual setup of Command Line Tools via the app menu. Ensure GPG signing is enabled in repo settings.