# dotfiles

Full bootstrap for a Linux workstation (Pop!_OS / Ubuntu 22.04). Clone and run
`install.sh` to install every tool, restore every config, and clone every project
repo to match the reference machine.

## Quick start (new machine)

```bash
# 1. Install Claude Code (or run the bootstrap directly — both work)
git clone https://github.com/lupontes/dotfiles ~/git/dotfiles
bash ~/git/dotfiles/install.sh
```

You'll be prompted for a **GitHub Personal Access Token** (repo scope). It is used
to clone private repos and to wire up Claude/Obsidian — it is **never written into
this repo**, only into local generated files.

The whole script is **idempotent** — safe to re-run.

## Structure

```
dotfiles/
├── install.sh                 ← orchestrator (packages → configs → repos)
├── packages.sh                ← system + dev tool installs
├── repos.sh                   ← clones project repos into ~/git
├── claude/
│   ├── CLAUDE.md              ← global preferences (symlinked)
│   └── settings.template.json ← Claude settings; token/home are placeholders
├── git/gitconfig              ← global git config (symlinked to ~/.gitconfig)
├── shell/bashrc.append.sh     ← nvm + PATH block appended to ~/.bashrc
├── vscode/extensions.txt      ← VS Code extensions (one id per line)
└── obsidian/brain/            ← config for the ~/brain vault
```

## What gets installed (`packages.sh`)

| Layer | Items |
|-------|-------|
| APT | git, curl, wget, zip, **openjdk-17-jdk**, **maven**, **postgresql(+contrib)**, flatpak |
| GitHub CLI | `gh` from the official apt repo |
| Docker | Docker CE + compose/buildx plugins; user added to `docker` group |
| Node | `nvm` + Node 18 (set as default) |
| Claude Code | `@anthropic-ai/claude-code` via npm |
| VS Code | snap `code` + all extensions in `vscode/extensions.txt` |
| Flatpak | Obsidian, Chrome Dev, OBS Studio, pgAdmin4, Insomnia |

## What gets configured

| Target | Action |
|--------|--------|
| `~/.gitconfig` | Symlinked to `git/gitconfig` |
| `~/.bashrc` | Appends the nvm/PATH managed block (once) |
| `~/.claude/CLAUDE.md` | Symlinked to `claude/CLAUDE.md` |
| `~/.claude/settings.json` | **Generated** from the template with token + `$HOME` injected |
| Claude memory | Clones `lupontes/claude-memory` into the memory dir |
| Obsidian `~/brain` | Installs Obsidian; clones the vault; symlinks config; writes obsidian-git auth |

## Project repos (`repos.sh`)

Cloned into `~/git`:

- **GitHub (token auth):** `tip` (+submodules tip-api/tip-web/tip-camunda), `projeto-publica`, `adubatec`
- **Embrapa internal (separate credentials):** `api`, `camunda`, `web`, `prototipo-tip-cti`
  — these use other hosts; the script clones them but auth may be prompted or skipped.

## Selective runs

```bash
SKIP_PACKAGES=1 bash install.sh   # configs + repos only
SKIP_REPOS=1     bash install.sh   # packages + configs only
```

## Secrets — NOT in this repo (restore manually)

These never leave the machine and must be recreated on a new box:

- **SSH keys** (`~/.ssh/id_ed25519*`) — generate a new key and add it to GitHub.
- **GitHub token** — provided interactively at install time (`credential.helper=store`
  persists it to `~/.git-credentials` after the first push).
- **Claude credentials** (`~/.claude/.credentials.json`) — re-created by `claude login`.
