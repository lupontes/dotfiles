#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then
    echo "already linked: $dest"
  elif [ -f "$dest" ]; then
    echo "backing up existing file: $dest -> $dest.bak"
    mv "$dest" "$dest.bak"
    ln -s "$src" "$dest"
    echo "linked: $dest"
  else
    ln -s "$src" "$dest"
    echo "linked: $dest"
  fi
}

link "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

MEMORY_DIR="$HOME/.claude/projects/-home-lupontes/memory"
if [ ! -d "$MEMORY_DIR/.git" ]; then
  mkdir -p "$(dirname "$MEMORY_DIR")"
  git clone https://github.com/lupontes/claude-memory.git "$MEMORY_DIR"
  echo "cloned: claude-memory"
else
  echo "already exists: claude-memory"
fi

OBSIDIAN_SB="$HOME/second brain/.obsidian"
for f in appearance.json app.json core-plugins.json graph.json; do
  link "$DOTFILES_DIR/obsidian/second-brain/$f" "$OBSIDIAN_SB/$f"
done

OBSIDIAN_OV="$HOME/Documentos/Obsidian Vault/.obsidian"
for f in appearance.json app.json community-plugins.json core-plugins.json graph.json; do
  link "$DOTFILES_DIR/obsidian/obsidian-vault/$f" "$OBSIDIAN_OV/$f"
done
link "$DOTFILES_DIR/obsidian/obsidian-vault/plugins/obsidian-git" "$OBSIDIAN_OV/plugins/obsidian-git"

echo ""
echo "dotfiles installed successfully."
