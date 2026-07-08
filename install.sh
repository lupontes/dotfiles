#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- GitHub token (used for cloning private repos and obsidian-git) ---
if [ -z "$GITHUB_TOKEN" ]; then
  echo "GitHub Personal Access Token (repo scope required):"
  read -r -s GITHUB_TOKEN
  echo ""
fi

# --- Helpers ---

link() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "$src" ]; then
      echo "already linked: $dest"
      return
    fi
    echo "updating stale symlink: $dest"
    rm "$dest"
    ln -s "$src" "$dest"
    echo "linked: $dest"
    return
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
  local app_id="$1"
  local name="$2"
  if flatpak info "$app_id" &>/dev/null; then
    echo "already installed: $name"
  else
    echo "installing: $name"
    flatpak install -y flathub "$app_id"
  fi
}

clone_private() {
  local repo="$1"
  local dest="$2"
  if [ ! -d "$dest/.git" ]; then
    git clone "https://lupontes:${GITHUB_TOKEN}@github.com/lupontes/$repo.git" "$dest"
    echo "cloned: $repo"
  else
    echo "already exists: $dest"
  fi
}

# --- Git global config ---
git config --global user.name  "Luciano Pontes"
git config --global user.email "luciano.pontes@embrapa.br"
git config --global init.defaultBranch main
git config --global core.excludesfile "$DOTFILES_DIR/git/gitignore_global"
echo "git: global config set"

# --- Claude Code ---
link "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

MEMORY_DIR="$HOME/.claude/projects/-home-lupontes/memory"
if [ ! -d "$MEMORY_DIR/.git" ]; then
  mkdir -p "$(dirname "$MEMORY_DIR")"
  git clone "https://lupontes:${GITHUB_TOKEN}@github.com/lupontes/claude-memory.git" "$MEMORY_DIR"
  echo "cloned: claude-memory"
else
  echo "already exists: claude-memory"
fi

# --- Obsidian ---
flatpak_install "md.obsidian.Obsidian" "Obsidian"

clone_private "brain" "$HOME/brain"

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

echo ""
echo "dotfiles installed successfully."
