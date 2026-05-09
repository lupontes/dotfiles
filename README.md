# dotfiles

Personal configuration files. Clone this repo and run `install.sh` to set up a new machine.

## Structure

```
dotfiles/
├── claude/CLAUDE.md   ← Claude Code global preferences
├── git/               ← git global config
└── shell/             ← shell aliases and config
```

## Installation

```bash
git clone https://github.com/lupontes/dotfiles ~/dotfiles
cd ~/dotfiles
bash install.sh
```

## Adding a new machine

Same as installation. The script is idempotent — safe to run multiple times.
