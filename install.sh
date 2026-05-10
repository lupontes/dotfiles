#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {
  local src="$1"
  local dest="$2"
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
  local app_id="$1"
  local name="$2"
  if flatpak info "$app_id" &>/dev/null; then
    echo "already installed: $name"
  else
    echo "installing: $name"
    flatpak install -y flathub "$app_id"
  fi
}

clone_vault() {
  local repo="$1"
  local dest="$2"
  if [ ! -d "$dest/.git" ]; then
    git clone "https://github.com/lupontes/$repo.git" "$dest"
    echo "cloned: $repo"
  else
    echo "already exists: $dest"
  fi
}

# --- Claude Code ---
link "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

MEMORY_DIR="$HOME/.claude/projects/-home-lupontes/memory"
if [ ! -d "$MEMORY_DIR/.git" ]; then
  mkdir -p "$(dirname "$MEMORY_DIR")"
  git clone https://github.com/lupontes/claude-memory.git "$MEMORY_DIR"
  echo "cloned: claude-memory"
else
  echo "already exists: claude-memory"
fi

# --- Obsidian ---
flatpak_install "md.obsidian.Obsidian" "Obsidian"

clone_vault "brain" "$HOME/brain"

OBSIDIAN_BRAIN="$HOME/brain/.obsidian"
mkdir -p "$OBSIDIAN_BRAIN/plugins"
for f in appearance.json app.json community-plugins.json core-plugins.json graph.json; do
  link "$DOTFILES_DIR/obsidian/brain/$f" "$OBSIDIAN_BRAIN/$f"
done
link "$DOTFILES_DIR/obsidian/brain/plugins/obsidian-git" "$OBSIDIAN_BRAIN/plugins/obsidian-git"

echo ""
echo "dotfiles installed successfully."
