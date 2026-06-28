#!/usr/bin/env bash
# Linux application + dev-tool environment (sourced by .profile on Linux).
# Provisioned by xtra/linux/workstation.sh.

# --- PATH: user-local + language toolchains ---
export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/.atuin/bin" ] && export PATH="$HOME/.atuin/bin:$PATH"   # atuin
[ -d "$HOME/.cargo/bin" ]   && export PATH="$HOME/.cargo/bin:$PATH"        # Rust
[ -d "$HOME/go/bin" ]       && export PATH="$PATH:$HOME/go/bin"            # Go
[ -d "$HOME/flutter/bin" ]  && export PATH="$PATH:$HOME/flutter/bin"       # Flutter
export PATH="$PATH:$HOME/.pub-cache/bin"                                   # Dart pub

# Android SDK
if [ -d "$HOME/Android/sdk" ]; then
  export ANDROID_HOME="$HOME/Android/sdk"
  export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin"
fi

# Node via fnm
if [ -x "$HOME/.local/share/fnm/fnm" ]; then
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$("$HOME/.local/share/fnm/fnm" env 2>/dev/null)" 2>/dev/null
fi

# --- aliases (Linux) ---
command -v eza    >/dev/null && { alias ls='eza --group-directories-first'; alias ll='eza -lah --git'; }
command -v batcat >/dev/null && alias bat='batcat'
command -v fdfind >/dev/null && alias fd='fdfind'
alias o.='xdg-open .'
command -v google-chrome >/dev/null && alias chrome='google-chrome'
alias ports='ss -tulpn 2>/dev/null || lsof -i | grep -E "(LISTEN|ESTABLISHED)"'
alias c.='repo_info -s 2>/dev/null; code "${git_local_path:-.}"'   # [E]dit repo in code
alias epc='code "$PROFILE_DIR" 2>/dev/null || vim "$PROFILE_DIR"'  # edit profile
alias ep='epc'

# --- interactive-only tool init ---
if [[ $- == *i* ]]; then
  command -v zoxide   >/dev/null && eval "$(zoxide init bash)"
  command -v starship >/dev/null && eval "$(starship init bash)"
  command -v atuin    >/dev/null && eval "$(atuin init bash)" 2>/dev/null
  [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash
fi
