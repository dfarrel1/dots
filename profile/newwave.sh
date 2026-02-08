#!/usr/bin/env bash
# Modern CLI tool integrations
# Install all: brew install zoxide fzf atuin bat eza git-delta fd ripgrep
# Each tool is guarded — missing tools are silently skipped.

# ── zoxide ───────────────────────────────────────────────────────────
# Smart cd replacement using frecency (frequency + recency).
# Learns which directories you use most and jumps to them by partial name.
#   z foo      → cd to the highest-ranked directory matching "foo"
#   zi foo     → interactive fuzzy picker for matches
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init bash)"
    # @desc Interactive zoxide directory jump (fuzzy search frecency-ranked dirs)
    alias zi='zi' # @desc Interactive zoxide directory picker
fi

# ── fzf ──────────────────────────────────────────────────────────────
# General-purpose fuzzy finder. Provides:
#   Ctrl-R  → fuzzy history search with preview
#   Ctrl-T  → fuzzy file finder (insert path at cursor)
#   Alt-C   → fuzzy cd into subdirectory
# Also pipeable: docker ps | fzf, git branch | fzf, etc.
if command -v fzf &>/dev/null; then
    eval "$(fzf --bash 2>/dev/null)" || {
        # fallback for older fzf versions that use sourced scripts
        local fzf_base
        fzf_base="$(brew --prefix fzf 2>/dev/null)"
        [ -f "$fzf_base/shell/completion.bash" ] && source "$fzf_base/shell/completion.bash"
        [ -f "$fzf_base/shell/key-bindings.bash" ] && source "$fzf_base/shell/key-bindings.bash"
    }

    export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"

    # Use fd for fzf if available (respects .gitignore, faster than find)
    if command -v fd &>/dev/null; then
        export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"
    fi

    # @desc Fuzzy-select a git branch and switch to it
    # @usage fbr
    fbr() {
        local branch
        branch=$(git branch --all | grep -v HEAD | sed 's/.* //' | sed 's#remotes/origin/##' | sort -u | fzf --height 40% --reverse)
        [ -n "$branch" ] && git checkout "$branch"
    }

    # @desc Fuzzy-search git log and show selected commit
    # @usage flog
    flog() {
        local commit
        commit=$(git log --oneline --color=always | fzf --ansi --preview 'git show --color=always {1}' | awk '{print $1}')
        [ -n "$commit" ] && git show "$commit"
    }

    # @desc Fuzzy-select and kill a process
    # @usage fkill [signal]
    fkill() {
        local pid
        pid=$(ps -ef | sed 1d | fzf --multi | awk '{print $2}')
        [ -n "$pid" ] && echo "$pid" | xargs kill "${1:--9}"
    }

    # @desc Preview files with bat (or cat) via fzf
    # @usage fpreview [query]
    fpreview() {
        local preview_cmd="cat {}"
        command -v bat &>/dev/null && preview_cmd="bat --style=numbers --color=always {}"
        fzf --preview "$preview_cmd" --query "${1:-}"
    }
fi

# ── atuin ────────────────────────────────────────────────────────────
# SQLite-backed shell history with context (directory, exit code, duration).
# Replaces Ctrl-R with a richer search. Optional encrypted sync across machines.
if command -v atuin &>/dev/null; then
    eval "$(atuin init bash --disable-up-arrow)"
fi

# ── bat ──────────────────────────────────────────────────────────────
# Cat replacement with syntax highlighting, line numbers, and git integration.
# Also works as a pager for man pages.
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never' # @desc cat with syntax highlighting (bat)
    alias catp='bat' # @desc bat with paging enabled
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# ── eza ──────────────────────────────────────────────────────────────
# Modern ls replacement with git status, icons, tree view, and color.
if command -v eza &>/dev/null; then
    alias ls='eza' # @desc ls with color and git status (eza)
    alias ll='eza -la --git' # @desc Long listing with git status (eza)
    alias la='eza -la --git' # @desc Long listing with git status (eza)
    alias lt='eza --tree --level=2' # @desc Tree view, 2 levels deep (eza)
    alias lt3='eza --tree --level=3' # @desc Tree view, 3 levels deep (eza)
    alias llt='eza -la --tree --level=2 --git' # @desc Long listing + tree (eza)
fi

# ── delta ────────────────────────────────────────────────────────────
# Better git diffs with syntax highlighting and line numbers.
# Configured via .gitconfig — see NEWWAVE.md for setup.
# No shell aliases needed; once configured, all git diffs use delta automatically.

# ── fd ───────────────────────────────────────────────────────────────
# Modern find replacement. Respects .gitignore, regex by default, fast.
if command -v fd &>/dev/null; then
    # @desc Find files by name pattern (fd)
    # @usage f <pattern>
    f() {
        fd "$@"
    }
fi

# ── ripgrep ──────────────────────────────────────────────────────────
# Fastest grep alternative. Respects .gitignore, recursive by default.
if command -v rg &>/dev/null; then
    # @desc Recursive grep with ripgrep (smart case, colors)
    # @usage rgs <pattern> [path]
    rgs() {
        rg --smart-case --color=always "$@" | less -R
    }
fi

# ── install helper ───────────────────────────────────────────────────
# @desc Install all modern CLI tools via Homebrew
# @usage install_newwave
install_newwave() {
    local tools=( zoxide fzf atuin bat eza git-delta fd ripgrep )
    local missing=()
    for tool in "${tools[@]}"; do
        if ! brew list "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done
    if [ ${#missing[@]} -eq 0 ]; then
        echo "All newwave tools are already installed."
    else
        echo "Installing: ${missing[*]}"
        brew install "${missing[@]}"
        echo ""
        echo "Done. Restart your shell or run 'src' to activate."
        echo "For delta, add to your ~/.gitconfig:"
        echo "  [core]"
        echo "    pager = delta"
        echo "  [interactive]"
        echo "    diffFilter = delta --color-only"
        echo "  [delta]"
        echo "    navigate = true"
        echo "    side-by-side = true"
    fi
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
