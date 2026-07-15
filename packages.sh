#!/usr/bin/env bash
# Installs all system packages and dev tools detected on the reference workstation.
# Idempotent: safe to run multiple times. Invoked by install.sh, but can run standalone.
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo -e "\n>>> $*"; }

# --- APT base packages ---
log "APT: base + dev packages"
sudo apt-get update -y

# Define apt packages array
apt_pkgs=(
  curl wget gzip zip unzip ca-certificates gnupg lsb-release
  git
  openjdk-17-jdk
  maven
  postgresql postgresql-contrib
  flatpak
)

# Migration tooling prerequisites
apt_pkgs+=(age zstd jq bats shellcheck)

sudo apt-get install -y "${apt_pkgs[@]}"

# --- GitHub CLI (gh) from official repo ---
if ! command -v gh >/dev/null 2>&1; then
  log "Installing GitHub CLI (gh)"
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -y && sudo apt-get install -y gh
else
  echo "already installed: gh"
fi

# --- Docker CE from official repo ---
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker CE"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER"
  echo "docker: added '$USER' to docker group (re-login required)"
else
  echo "already installed: docker"
fi

# --- nvm + Node 18 ---
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  log "Installing nvm"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
if ! nvm ls 18 >/dev/null 2>&1; then
  log "Installing Node 18 via nvm"
  nvm install 18
  nvm alias default 18
else
  echo "already installed: node 18"
fi

# --- Claude Code CLI (global npm) ---
if ! command -v claude >/dev/null 2>&1; then
  log "Installing Claude Code CLI"
  npm install -g @anthropic-ai/claude-code
else
  echo "already installed: claude code"
fi

# --- VS Code (snap) + extensions ---
if ! command -v code >/dev/null 2>&1; then
  log "Installing VS Code (snap)"
  sudo snap install code --classic
else
  echo "already installed: vscode"
fi
if command -v code >/dev/null 2>&1 && [ -f "$DOTFILES_DIR/vscode/extensions.txt" ]; then
  log "VS Code extensions"
  while IFS= read -r ext; do
    [ -z "$ext" ] && continue
    code --install-extension "$ext" --force
  done < "$DOTFILES_DIR/vscode/extensions.txt"
fi

# --- Flatpak apps ---
log "Flatpak apps"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
for app in com.google.ChromeDev com.obsproject.Studio org.pgadmin.pgadmin4 rest.insomnia.Insomnia; do
  if flatpak info "$app" &>/dev/null; then
    echo "already installed: $app"
  else
    flatpak install -y flathub "$app"
  fi
done

log "packages.sh finished"
