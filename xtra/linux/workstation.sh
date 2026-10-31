#!/usr/bin/env bash
# ------------------------------------------------------------------
# [PUBLIC] LINUX WORKSTATION PROVISIONER (Idempotent, Ubuntu 24.04/26.04)
#
# Fills the gaps newcomp.sh / Aptfile don't cover for a full dev box:
# modern CLI (New Wave), tmux/zellij, starship, Node(fnm), Docker(official),
# Podman, Flutter + Android SDK (+KVM), code-server, gh, Tailscale.
#
# Runs WITHOUT your 1Password identity (no secrets restored).
# Re-runnable: every module guards on a marker in xtra/.state/.
#
#   ./workstation.sh                 # run all modules
#   ./workstation.sh base cli docker # run only listed modules
#   ./workstation.sh --list          # show modules
#   FORCE=1 ./workstation.sh docker  # ignore the state marker, re-run
# ------------------------------------------------------------------
set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &>/dev/null && pwd )"
STATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/.state"
mkdir -p "$STATE_DIR"
: "${FORCE:=}"

log()  { printf '   -> %s\n' "$*"; }
ok()   { printf '   \033[32m%s\033[0m\n' "OK: $*"; }
skip() { printf '   %s: skipped (already done)\n' "$1"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

done_marker() { [[ -z "$FORCE" && -f "$STATE_DIR/$1" ]]; }
mark()        { touch "$STATE_DIR/$1"; }
# One apt batch fails as a whole when any package has no candidate on this release
# (26.04 dropped tldr), so install what exists and name what does not.
APT() {
  local have=() gone=() p
  for p in "$@"; do
    # apt-cache show also lists virtual/transitional names; only a real candidate installs
    case "$(apt-cache policy "$p" 2>/dev/null | awk '/Candidate:/{print $2}')" in
      ""|"(none)") gone+=("$p") ;;
      *) have+=("$p") ;;
    esac
  done
  ((${#gone[@]})) && log "no apt candidate on this release, skipped: ${gone[*]}"
  ((${#have[@]})) && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${have[@]}"
}

mod_base() {
  done_marker linux_base_complete && { skip base; return; }
  hdr "base packages"
  sudo apt-get update -qq
  APT build-essential curl wget git git-lfs gnupg ca-certificates \
      software-properties-common apt-transport-https jq unzip zip \
      zsh tmux htop tldr direnv pipx python3-venv openjdk-17-jdk golang-go
  mark linux_base_complete; ok "base packages installed"
}

mod_cli() {
  done_marker linux_cli_complete && { skip cli; return; }
  hdr "modern CLI (New Wave)"
  APT fzf ripgrep fd-find bat zoxide git-delta
  if ! command -v eza >/dev/null; then
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null || true
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
      | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
    sudo apt-get update -qq && APT eza || log "eza repo unavailable, skipping"
  fi
  command -v atuin >/dev/null || setsid bash -c 'curl -fsSL https://setup.atuin.sh | bash' </dev/null >/dev/null 2>&1 || true
  command -v starship >/dev/null || curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
  mkdir -p "$HOME/.local/bin"
  [ -e /usr/bin/fdfind ] && ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"
  [ -e /usr/bin/batcat ] && ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
  mark linux_cli_complete; ok "modern CLI installed"
}

mod_tmux() {
  done_marker linux_tmux_complete && { skip tmux; return; }
  hdr "tmux + zellij (persistent sessions)"
  command -v tmux >/dev/null || APT tmux
  if ! command -v zellij >/dev/null; then
    local ver; ver=$(curl -fsSL https://api.github.com/repos/zellij-org/zellij/releases/latest | grep -oE '"tag_name": "[^"]+"' | head -1 | cut -d'"' -f4)
    curl -fsSL "https://github.com/zellij-org/zellij/releases/download/${ver}/zellij-x86_64-unknown-linux-musl.tar.gz" \
      | sudo tar xz -C /usr/local/bin && log "zellij ${ver} installed" || log "zellij install skipped"
  fi
  if [ ! -f "$HOME/.tmux.conf" ]; then
    cat > "$HOME/.tmux.conf" <<'TMUXCONF'
set -g mouse on
set -g history-limit 100000
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
setw -g mode-keys vi
set -g base-index 1
setw -g pane-base-index 1
bind r source-file ~/.tmux.conf \; display "reloaded"
set -g status-right "#H  %H:%M"
TMUXCONF
    log "wrote ~/.tmux.conf"
  fi
  mark linux_tmux_complete; ok "tmux + zellij ready"
}

mod_node() {
  done_marker linux_node_complete && { skip node; return; }
  hdr "Node.js (fnm + LTS)"
  mkdir -p "$HOME/.local/bin"
  if ! command -v fnm >/dev/null && [ ! -x "$HOME/.local/bin/fnm" ]; then
    curl -fsSL https://github.com/Schniz/fnm/releases/latest/download/fnm-linux.zip -o /tmp/fnm.zip \
      && unzip -o /tmp/fnm.zip -d "$HOME/.local/bin" >/dev/null && chmod +x "$HOME/.local/bin/fnm"
  fi
  export PATH="$HOME/.local/bin:$PATH"
  if command -v fnm >/dev/null; then
    eval "$(fnm env --shell bash)" || true
    fnm install --lts && fnm default lts-latest || log "fnm LTS issue"
  fi
  mark linux_node_complete; ok "Node (fnm) installed"
}

mod_rust() {
  { done_marker rust_complete || done_marker linux_rust_complete; } && { skip rust; return; }
  hdr "Rust (rustup)"
  command -v rustc >/dev/null || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  mark linux_rust_complete; ok "Rust installed"
}

mod_docker() {
  done_marker linux_docker_complete && { skip docker; return; }
  hdr "Docker (official repo)"
  if ! command -v docker >/dev/null; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    local codename; codename=$(. /etc/os-release; echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -qq
    APT docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
      || { log "official repo failed ($codename), falling back to docker.io"; APT docker.io docker-compose-v2; }
  fi
  sudo usermod -aG docker "$USER" || true
  sudo systemctl enable --now docker 2>/dev/null || true
  mark linux_docker_complete; ok "Docker installed (re-login for group)"
}

mod_podman() {
  done_marker linux_podman_complete && { skip podman; return; }
  hdr "Podman"
  command -v podman >/dev/null || APT podman
  command -v podman-compose >/dev/null || pipx install podman-compose 2>/dev/null || true
  mark linux_podman_complete; ok "Podman installed"
}

mod_gh() {
  done_marker linux_gh_complete && { skip gh; return; }
  hdr "GitHub CLI (gh)"
  if ! command -v gh >/dev/null; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -qq && APT gh
  fi
  mark linux_gh_complete; ok "gh installed"
}

mod_android() {
  done_marker linux_android_complete && { skip android; return; }
  hdr "Flutter + Android SDK (KVM emulator)"
  APT openjdk-17-jdk unzip libglu1-mesa qemu-system-x86 || APT qemu-system-x86 || true
  sudo usermod -aG kvm "$USER" || true
  local SDK="$HOME/Android/sdk"
  if [ ! -d "$SDK/cmdline-tools/latest" ]; then
    mkdir -p "$SDK/cmdline-tools"
    local url; url=$(curl -fsSL https://developer.android.com/studio | grep -oE 'https://dl.google.com/android/repository/commandlinetools-linux-[0-9]+_latest.zip' | head -1)
    curl -fsSL "$url" -o /tmp/cmdtools.zip && unzip -q /tmp/cmdtools.zip -d "$SDK/cmdline-tools" \
      && mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"
  fi
  export ANDROID_HOME="$SDK"
  local SDKMGR="$SDK/cmdline-tools/latest/bin/sdkmanager"
  if [ -x "$SDKMGR" ]; then
    yes | "$SDKMGR" --licenses >/dev/null 2>&1 || true
    "$SDKMGR" "platform-tools" "build-tools;34.0.0" "platforms;android-34" "emulator" >/dev/null 2>&1 || log "sdkmanager partial"
  fi
  [ -d "$HOME/flutter" ] || git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter"
  mark linux_android_complete; ok "Flutter + Android SDK installed"
}

mod_codeserver() {
  done_marker linux_codeserver_complete && { skip code-server; return; }
  hdr "code-server (browser VS Code)"
  command -v code-server >/dev/null || curl -fsSL https://code-server.dev/install.sh | sh
  sudo systemctl enable --now "code-server@$USER" 2>/dev/null || true
  log "config: ~/.config/code-server/config.yaml (set bind-addr 0.0.0.0:8080 for LAN, password inside)"
  mark linux_codeserver_complete; ok "code-server installed"
}

mod_tailscale() {
  done_marker linux_tailscale_complete && { skip tailscale; return; }
  hdr "Tailscale (optional mesh)"
  command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh
  log "run 'sudo tailscale up' to join your tailnet"
  mark linux_tailscale_complete; ok "Tailscale installed"
}

mod_netbird() {  # NetBird mesh client (enrollment is manual + needs a setup key)
  done_marker linux_netbird_complete && { skip netbird; return; }
  hdr "NetBird mesh client"
  command -v netbird >/dev/null || curl -fsSL https://pkgs.netbird.io/install.sh | sh
  log "enroll manually: sudo netbird up --management-url <URL> --setup-key <KEY>"
  mark linux_netbird_complete; ok "NetBird client installed"
}

mod_ollama() {  # local LLM runtime; pulls NO model (RAM-safe until you run one)
  done_marker linux_ollama_complete && { skip ollama; return; }
  hdr "Ollama (LLM runtime, no model pulled)"
  command -v ollama >/dev/null || curl -fsSL https://ollama.com/install.sh | sh
  log "run a model on demand, e.g.: ollama run qwen2.5-coder:3b"
  mark linux_ollama_complete; ok "Ollama installed (no model pulled)"
}

ALL_MODULES=(base cli tmux node rust docker podman gh android codeserver netbird ollama tailscale)
[[ "${1:-}" == "--list" ]] && { printf 'modules: %s\n' "${ALL_MODULES[*]}"; exit 0; }
RUN=("$@"); [[ ${#RUN[@]} -eq 0 ]] && RUN=("${ALL_MODULES[@]}")
echo "Linux workstation provisioner - modules: ${RUN[*]}"
for m in "${RUN[@]}"; do
  if declare -F "mod_$m" >/dev/null; then "mod_$m"; else echo "   ?? unknown module: $m"; fi
done
echo; echo "Done. Re-login (or 'newgrp docker') so docker/kvm group membership applies."
