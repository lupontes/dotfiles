# dotfiles

Personal configuration files for Linux workstations. Clone and run `install.sh` to replicate the setup.

## Structure

```
dotfiles/
├── claude/
│   └── CLAUDE.md              ← Claude Code global preferences
└── obsidian/
    └── brain/                 ← Config for ~/brain vault
        ├── app.json
        ├── appearance.json
        ├── community-plugins.json
        ├── core-plugins.json
        ├── graph.json
        └── plugins/
            └── obsidian-git/  ← Auto-commit + push every 10 min
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
| Obsidian | Installs via Flatpak; clones `lupontes/brain` to `~/brain`; symlinks config |

## Vault sync

Notes are versioned in a private GitHub repo and synced automatically by the obsidian-git plugin (commit + push every 10 minutes while Obsidian is open).

Vault: `~/brain` → `github.com/lupontes/brain` (private)
