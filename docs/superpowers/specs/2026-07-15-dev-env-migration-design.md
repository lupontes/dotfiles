# Dev Environment Migration — Design Spec

**Date:** 2026-07-15
**Author:** lupontes (with Claude Code)
**Home repo:** `dotfiles` (the workstation-bootstrap repo — extends existing `install.sh`, `packages.sh`, `repos.sh`)
**Status:** Approved for planning

## Goal

Migrate the entire development environment of workstation `lupontes` to a fresh
machine running the latest available **Ubuntu Desktop** (as of this date the newest
is ~26.04 LTS; the scripts are **version-agnostic** and hard-code no release). After
restore, the developer must be able to resume work as if on the original machine:
all projects, Claude Code and its plugins/config, the claude-mem remote connection
(tested), and the Mimo Code AI, all functional.

**Key path change:** projects live in `~/git` on the source and must live in
`~/repo` on the destination.

## Constraints & decisions (locked)

- **Git safety:** interactive, repo-by-repo review. Nothing is pushed to any remote
  without explicit per-repo approval. Company remotes (`git.embrapa.io`,
  `git-cnpmf.nuvem.ti.embrapa.br`) are treated with extra care.
- **Transport:** a single encrypted archive (`age` + strong passphrase) containing
  everything, secrets included. Moved to the new machine by the user (USB/scp).
- **claude-mem remote:** simplest, fully automated path — reuse the existing API key
  and `project_id` from the backup, keep URL on port **443** (bypasses the corporate
  firewall), install the Caddy CA cert. **No new key minting, no SSH to the server,
  no firewall changes.** Connectivity is tested automatically at the end of restore.
- **`~/git/brain`** (not a git repo): captured in the encrypted backup only, restored
  to `~/repo/brain`. No remote versioning.
- **claude-mem local memory** (`~/.claude-mem`, ~7 MB db + chroma): **included** in the
  backup for immediate memory continuity on the new machine.
- **Prerequisites:** the restore installs every prerequisite for Claude Code to be
  fully functional (runtimes, CLI, plugins, MCP servers) plus the toolchains the
  projects need (Java/Maven, .NET).

## Source-machine facts (discovered)

### Projects in `~/git`

| Project | Type | Remote | Notes |
|---|---|---|---|
| adubatec | git | github.com/lupontes | clean |
| api | git | git.embrapa.io/publica | clean, branch `refact/refatoracaoEtapaService` |
| brain | **not git** | — | local only → backup-only |
| camunda | git | git.embrapa.io/publica | clean, branch `release` |
| claude-memory | git | github.com/lupontes | clean |
| dotfiles | git | github.com/lupontes | 1 dirty (`claude/CLAUDE.md`); **this repo** |
| projeto-publica | git + **submodules** | git.embrapa.io/publica | umbrella, clean |
| prototipo-tip-cti | git | git-cnpmf.nuvem.ti.embrapa.br | 3 dirty + **1 unpushed commit** |
| prototipo-tip-cti_bkp | git | same as above | **15 dirty** |
| server-test | git | github.com/lupontes | 1 dirty; branch `handoff/claude-mem-server-beta` |
| tip | git + **submodules** | github.com/lupontes | umbrella, 5 dirty |
| web | git | git.embrapa.io/publica | branch `feat/ordemMenu` **has no upstream** |

### claude-mem connection (current, working)

- `~/.claude/settings.json` env: `CLAUDE_MEM_RUNTIME=server-beta`,
  `CLAUDE_MEM_SERVER_BETA_URL=https://163.176.168.207:443`, API key present,
  `CLAUDE_MEM_SERVER_BETA_PROJECT_ID=48e2759b-2cd3-4336-9601-3b3dce28b957`,
  `NODE_EXTRA_CA_CERTS=~/.claude/caddy-root.crt`.
- CA cert present: `~/.claude/caddy-root.crt` (valid → 2036).
- Live connectivity test (from the corporate network, 2026-07-15): **TCP 443 OK**,
  **TCP 37700 blocked** (confirms the firewall + that the 443 route solves it),
  TLS chain validates via the CA cert. `503` on `/` is the expected viewer response.
- Local per-project sync corpora: `projeto-publica`, `tip`, `git`, `server-test`,
  `lupontes`. The **`git` corpus must be remapped to `repo`** on the destination.
- `~/.claude-mem/.cwd-remap-applied-v1` exists → claude-mem supports cwd remapping,
  which the `~/git`→`~/repo` move requires.

> The authoritative, up-to-date network-security and connection reference lives on
> the **remote** branch `origin/feature/oracle-cloud-infra` of `server-test`
> (`docs/CLAUDE_MEM_SERVER.md`, `docs/SECURITY-RECOMMENDATIONS.md`, `docs/PORTS.md`),
> which is ahead of the local `HANDOFF.md`. The 443 route was added there on 12/07.

### Mimo Code

- npm package `@mimo-ai/plugin@0.1.4` installed under `~/.mimocode`
  (launcher `~/.mimocode/bin/mimo`, plus custom `command/` and `skills/`).
- Reinstall = `npm i @mimo-ai/plugin@0.1.4` + restore `command/` and `skills/` +
  put `bin/mimo` on PATH + verify it runs. Depends on Node.

### SSH keys present on source

`~/.ssh/id_ed25519` (personal), `~/.ssh/claude-mem-tunnel` (tunnel; likely obsolete
now that 443 works), `known_hosts`. **`~/.ssh/oci_vms` is NOT present here** — so this
machine cannot SSH to the OCI server; the chosen restore path does not need it.

## Architecture — three phases + a manifest

### Phase 0 — Git safety (interactive, run before backup)

A guided routine, repo by repo, over `~/git`:

1. For each repo with a dirty tree or unpushed commits: show `git status` + `git diff`,
   propose a Conventional Commits message, commit **only after approval**, then push
   **only after approval**.
2. Special handling:
   - `web`: `feat/ordemMenu` has no upstream → set upstream and push (after approval).
   - `prototipo-tip-cti`: push the existing unpushed commit (after approval).
   - `prototipo-tip-cti_bkp` (15 dirty): review carefully — may be a throwaway backup;
     confirm whether its changes should be committed or only captured in the archive.
   - Umbrellas `tip` and `projeto-publica`: after submodule commits, commit the
     submodule-pointer bump in the umbrella (after approval).
   - `brain`: not git → no commit; captured by the backup archive.
3. **Output:** a report asserting, per repo, either "clean & pushed" or
   "captured in archive only" — so there is an explicit zero-loss guarantee.

### Phase 1 — `backup.sh` (source machine)

Produces one encrypted archive `dev-env-backup-YYYYMMDD.tar.zst.age`. Contents:

- **Projects:** entire `~/git` working trees, including untracked/ignored files,
  `.env`, local-only branches, and the non-git `brain`. (Belt-and-suspenders on top
  of the pushes from Phase 0.)
- **Claude Code:** `~/.claude/` (settings.json, plugins, skills, agents,
  `caddy-root.crt`), `~/.claude.json`, `~/.claude-mem/` (db, chroma, corpora,
  settings — preserves memory).
- **Mimo Code:** `~/.mimocode/` (incl. `command/`, `skills/`, package files).
- **Toolchain configs:** `~/.gitconfig`, `~/.ssh/` (keys — the reason the archive is
  encrypted), `~/.m2/settings.xml` if present, node/bun/java/dotnet version pins,
  relevant `~/.config` subset.
- **`manifest.json`:** source paths, tool versions, the `~/git`→`~/repo` remap rule,
  claude-mem `project_id` + URL(443) + corpus→corpus remap (`git`→`repo`), and the
  list of relevant apt/snap packages.

Encryption with `age` (passphrase). Archive integrity is verified after creation.

### Phase 2 — `restore.sh` (fresh Ubuntu Desktop; idempotent)

1. **Apt prerequisites:** build-essential, git, curl, ca-certificates, age, zstd, jq.
2. **Runtimes (from manifest):** nvm + Node (same major), bun, Java (for `~/.m2`
   projects), .NET (if projects need it).
3. **Decrypt + extract** the archive (prompt for passphrase).
4. **Projects → `~/repo`** (remapped from `~/git`).
5. **Claude Code:** install the CLI, restore `~/.claude` + `~/.claude.json`, install
   plugins (superpowers, claude-mem) and MCP servers. **Remap `~/git`→`~/repo`**
   everywhere: `~/.claude.json` project keys, settings paths, and the claude-mem
   cwd remap.
6. **claude-mem remote:** restore `~/.claude-mem`; install `caddy-root.crt` into the
   system trust store (`update-ca-certificates`) and `NODE_EXTRA_CA_CERTS`; keep
   URL on **:443**; reuse the API key + `project_id` from the backup; remap the
   `git` corpus to `repo`. Then **run the connectivity test**
   (TCP 443 + `curl --cacert` + Bearer) and assert PASS.
7. **Mimo Code:** `npm i @mimo-ai/plugin@0.1.4` into `~/.mimocode`, restore
   `command/` + `skills/`, ensure `bin/mimo` on PATH, verify `mimo` runs.
8. **Permissions & identity:** `~/.ssh` keys to 600, gitconfig, known_hosts.
9. **Final verification report:** node/bun/java/dotnet versions, `claude --version`,
   plugins loaded, **claude-mem 443 test = PASS**, `mimo` OK, and per-project git
   remote reachability + status under `~/repo`.

### Phase 3 — Cloud service / project-id evaluation

The "cloud service" is the OCI claude-mem server. The active `project_id`s are read
from the local sync-state (which already reflects the server association) plus the
pinned `48e2759b-…`. On restore the **`git` corpus is remapped to `repo`** so memory
reconnects under the new path. This needs **no server access**. An optional server-side
confirmation (Postgres rows) would require `~/.ssh/oci_vms`, which is not on this
machine and is out of scope for the simplest automated path.

## Integration with existing `dotfiles`

`dotfiles` already has `install.sh`, `packages.sh`, `repos.sh`, and `claude/`,
`shell/`, `vscode/` config. The migration scripts **extend** these rather than
duplicate:
- `repos.sh` currently targets `~/git` → parameterize it for `~/repo` (`REPO_ROOT`).
- `restore.sh` orchestrates `packages.sh` → runtimes → extract → `repos.sh` →
  Claude Code → claude-mem → Mimo Code → verify.
- `backup.sh` is new.

## Testing

- **Phase 0:** dry-run reporting (`git status --porcelain`, `@{u}..HEAD`) before any
  write; post-run assertion that every repo is clean & pushed or explicitly
  archive-only.
- **backup.sh:** verify the archive decrypts and lists a non-empty file tree; assert
  the presence of key paths (projects, `~/.claude`, `~/.claude-mem`, `~/.mimocode`,
  ssh keys, manifest) before declaring success.
- **restore.sh:** the built-in final verification report is the integration test —
  runtimes resolve, `claude --version` works, plugins load, the claude-mem 443
  connectivity test passes, `mimo` runs, and each `~/repo` project reaches its remote.
  Idempotency: re-running restore must not corrupt an already-restored environment.

## Honest limitations

- Cannot SSH to the OCI server from this machine (no `oci_vms` key); the chosen path
  does not require it.
- "Latest Ubuntu Desktop" is resolved at install time on the destination; the scripts
  target whatever release is freshly installed and hard-code none.
- `503` on the claude-mem `/` endpoint is the viewer response; true end-to-end sync
  proof would be server-side (Postgres), which is optional and out of scope here.
