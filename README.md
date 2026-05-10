# dotfiles

Personal configuration files for Linux workstations. Clone and run `install.sh` to replicate the setup.

## Structure

```
dotfiles/
├── claude/
│   └── CLAUDE.md                         ← Claude Code global preferences
└── obsidian/
    ├── second-brain/                      ← Config for ~/second brain vault
    │   ├── app.json
    │   ├── appearance.json
    │   ├── core-plugins.json
    │   └── graph.json
    └── obsidian-vault/                    ← Config for ~/Documentos/Obsidian Vault
        ├── app.json
        ├── appearance.json
        ├── community-plugins.json
        ├── core-plugins.json
        ├── graph.json
        └── plugins/
            └── obsidian-git/
```

## Installation

```bash
git clone https://github.com/lupontes/dotfiles ~/dotfiles
bash ~/dotfiles/install.sh
```

The script is idempotent — safe to run multiple times.

## What the script does

| Step | Action |
|------|--------|
| Claude Code | Symlinks `CLAUDE.md` to `~/.claude/CLAUDE.md` |
| Claude Memory | Clones `lupontes/claude-memory` into the Claude memory directory |
| Obsidian | Installs via Flatpak if not present; symlinks config files for both vaults |

## After installation

The vault **content** (notes) is not managed by this repo. Sync it separately via Syncthing or another tool before opening Obsidian.

Vault paths expected on every machine:
- `~/second brain/`
- `~/Documentos/Obsidian Vault/`
