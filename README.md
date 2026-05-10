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
    │   ├── community-plugins.json
    │   ├── core-plugins.json
    │   └── graph.json
    └── obsidian-vault/                    ← Config for ~/Documentos/Obsidian Vault
        ├── app.json
        ├── appearance.json
        ├── community-plugins.json
        ├── core-plugins.json
        ├── graph.json
        └── plugins/
            └── obsidian-git/             ← Shared by both vaults
                ├── data.json             ← Auto-commit every 10 min, auto-push every 10 min
                ├── main.js
                ├── manifest.json
                └── styles.css
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
| Obsidian | Installs via Flatpak; clones both vault repos; symlinks all config files |

## Vault sync

Notes are versioned in private GitHub repos and synced automatically by the obsidian-git plugin (commit + push every 10 minutes while Obsidian is open).

| Vault | Repo |
|-------|------|
| `~/second brain` | `github.com/lupontes/second-brain` (private) |
| `~/Documentos/Obsidian Vault` | `github.com/lupontes/obsidian-vault` (private) |
