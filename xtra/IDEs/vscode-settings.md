# vscode settings

### Backup gist

[settings-gist](https://gist.github.com/dfarrel1/a6bd450e6ce1355890c6c8bfafb737f3)

Contains:
- `settings.json` — editor settings
- `keybindingsMac.json` — keybindings
- `extensions.json` — installed extensions list
- `install-extensions.sh` — bootstrap script for fresh machines

### Settings Sync (built-in)

VSCode has built-in Settings Sync — no plugin needed. Sign in with your GitHub account via the gear icon in the bottom-left corner, and settings/extensions/keybindings sync automatically across machines.

The gist above is a manual backup for cases where you need to bootstrap without signing in first, or want a snapshot outside of Microsoft's sync.

### Bootstrap extensions on a new machine

```bash
bash xtra/IDEs/install-vscode-exts.sh
```

### Custom keybinding

settings json file: shift+alt+cmd+p
