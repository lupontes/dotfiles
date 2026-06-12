#!/usr/bin/env bash
# Bootstraps a fresh Linux workstation to match the reference setup.
# Idempotent — safe to run multiple times.
#
# Usage:
#   bash install.sh              # full setup (packages + configs + repos)
#   SKIP_PACKAGES=1 bash install.sh   # configs + repos only
#   SKIP_REPOS=1     bash install.sh   # packages + configs only
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- GitHub token (used for cloning private repos and obsidian-git) ---
if [ -z "$GITHUB_TOKEN" ]; then
  echo "GitHub Personal Access Token (repo scope required):"
  read -r -s GITHUB_TOKEN
  echo ""
fi
export GITHUB_TOKEN

# --- Helpers ---

link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then
    echo "already linked: $dest"
  elif [ -e "$dest" ]; then
    echo "backing up: $dest -> $dest.bak"
    mv "$dest" "$dest.bak"
    ln -s "$src" "$dest"
    echo "linked: $dest"
  else
    ln -s "$src" "$dest"
    echo "linked: $dest"
  fi
}

flatpak_install() {
  local app_id="$1" name="$2"
  if flatpak info "$app_id" &>/dev/null; then
    echo "already installed: $name"
  else
    echo "installing: $name"
    flatpak install -y flathub "$app_id"
  fi
}

# ============================================================
# 1. System packages and dev tools
# ============================================================
if [ -z "$SKIP_PACKAGES" ]; then
  bash "$DOTFILES_DIR/packages.sh"
else
  echo "SKIP_PACKAGES set — skipping system packages"
fi

# ============================================================
# 2. Shell + Git config
# ============================================================
# .bashrc managed block (idempotent: only appended once)
if ! grep -q "dotfiles managed block" "$HOME/.bashrc" 2>/dev/null; then
  cat "$DOTFILES_DIR/shell/bashrc.append.sh" >> "$HOME/.bashrc"
  echo "bashrc: managed block appended"
else
  echo "already present: bashrc managed block"
fi

link "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"

# ============================================================
# 3. Claude Code
# ============================================================
link "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# settings.json is generated (not symlinked) so the live token never lands in git.
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
sed -e "s|__GITHUB_TOKEN__|${GITHUB_TOKEN}|g" \
    -e "s|__HOME__|${HOME}|g" \
    "$DOTFILES_DIR/claude/settings.template.json" > "$CLAUDE_SETTINGS"
echo "claude: settings.json generated from template"

# claude-memory repo into the Claude memory directory
MEMORY_DIR="$HOME/.claude/projects/-home-lupontes/memory"
if [ ! -d "$MEMORY_DIR/.git" ]; then
  mkdir -p "$(dirname "$MEMORY_DIR")"
  git clone "https://lupontes:${GITHUB_TOKEN}@github.com/lupontes/claude-memory.git" "$MEMORY_DIR"
  echo "cloned: claude-memory"
else
  echo "already exists: claude-memory"
fi

# ============================================================
# 4. Obsidian
# ============================================================
flatpak_install "md.obsidian.Obsidian" "Obsidian"

if [ ! -d "$HOME/brain/.git" ]; then
  git clone "https://lupontes:${GITHUB_TOKEN}@github.com/lupontes/brain.git" "$HOME/brain"
  echo "cloned: brain"
else
  echo "already exists: $HOME/brain"
fi

OBSIDIAN_BRAIN="$HOME/brain/.obsidian"
mkdir -p "$OBSIDIAN_BRAIN/plugins"
for f in appearance.json app.json community-plugins.json core-plugins.json graph.json; do
  link "$DOTFILES_DIR/obsidian/brain/$f" "$OBSIDIAN_BRAIN/$f"
done
link "$DOTFILES_DIR/obsidian/brain/plugins/obsidian-git" "$OBSIDIAN_BRAIN/plugins/obsidian-git"

OBSIDIAN_GIT_DATA="$OBSIDIAN_BRAIN/plugins/obsidian-git/data.json"
if [ ! -f "$OBSIDIAN_GIT_DATA" ]; then
  cat > "$OBSIDIAN_GIT_DATA" << ENDJSON
{
  "commitMessage": "vault backup: {{date}}",
  "autoSaveInterval": 10,
  "autoPushInterval": 10,
  "syncMethod": "merge",
  "pullBeforePush": true,
  "disablePopups": false,
  "listChangedFilesInMessageBody": false,
  "showStatusBar": true,
  "updateSubmodules": false,
  "mergeOnCheckout": true,
  "customMessageOnAutoBackup": false,
  "autoBackupAfterFileChange": false,
  "treeStructure": false,
  "refreshSourceControl": true,
  "basePath": "",
  "differentIntervalCommitAndPush": false,
  "changedFilesInStatusBar": false,
  "username": "lupontes",
  "password": "$GITHUB_TOKEN"
}
ENDJSON
  echo "obsidian-git: data.json created"
else
  echo "already exists: obsidian-git/data.json"
fi

# ============================================================
# 5. Project repositories
# ============================================================
if [ -z "$SKIP_REPOS" ]; then
  bash "$DOTFILES_DIR/repos.sh"
else
  echo "SKIP_REPOS set — skipping project repos"
fi

echo ""
echo "dotfiles installed successfully."
echo "NOTE: log out/in (or 'newgrp docker') so the docker group and nvm take effect."
