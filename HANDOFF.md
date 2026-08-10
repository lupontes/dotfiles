# Handoff: Dev-Environment Migration Tooling (`dotfiles`)

**Updated:** 2026-08-10
**Branch:** `feat/env-migration` (in `~/git/dotfiles`)
**HEAD:** `ccba5ed`
**Status:** Tooling build complete (lean scope, see below). All 26 bats tests pass,
shellcheck clean. Live run (commit/push + real backup) has NOT started yet.

## Goal (narrowed 2026-08-10, before an OS reformat)

Back up workstation `lupontes` before formatting to a fresh Ubuntu Desktop:
commit+push every project for safety, then produce one plaintext archive and a
`restore.sh` that — after Claude Code is installed **manually** on the new
machine — recreates every project under `~/repos` (renamed from the earlier
`~/repo` singular) and reinstalls Claude Code plugins from their official
marketplaces, so the working "harness" (skills + plugins) comes back functional.

**Explicitly out of scope for this pass** (code for all of it already exists in
`docs/superpowers/plans/2026-07-15-dev-env-migration.md` if resumed later):
claude-mem CA install + connectivity test, Mimo Code reinstall, runtime installers
(node/bun/java/dotnet) wired into `restore.sh`. `packages.sh` still covers the
general fresh-machine bootstrap path independently.

## How to resume

1. `cd ~/git/dotfiles && git checkout feat/env-migration`
2. Read `README.md` → "Migration to a new machine" for the current usage.
3. Everything below "Completed" is done and tested. Nothing is stubbed.

## Locked decisions (do NOT re-litigate)

- **Git safety:** interactive, repo-by-repo. Nothing pushed to any remote without
  explicit per-repo approval (`git_safety_interactive` in `lib/git_safety.sh`).
- **Archive: PLAINTEXT `tar.zst`, NO encryption.** Treat it as a secret; wipe
  media + delete residual archive after restore.
- **Programs from official sources only.** Backup carries config/data/projects,
  never installed program trees (`.claude/plugins/{cache,marketplaces}`,
  `.mimocode/node_modules`, etc. excluded via `ARCHIVE_EXCLUDE_FILE`).
- **Projects: `~/git` (source) → `~/repos` (destination)**, not `~/repo` singular
  — renamed mid-build at user request. `REPO_ROOT` env var overrides.
- **`~/git/brain`** (not a git repo): captured in the archive only, no special
  restore logic needed (moves with the rest of `git/`).

## Completed & committed (branch `feat/env-migration`)

- **Tasks 1–4** (prior session, unchanged): `lib/common.sh`, `lib/manifest.sh`,
  `lib/git_safety.sh`, `lib/archive.sh` (plaintext tar.zst, PIPESTATUS failure
  detection, `ARCHIVE_EXCLUDE_FILE` support).
- **Task 5** — `repos.sh` parameterized: `REPO_ROOT` defaults to `$HOME/repos`.
  Commit `f73626f`.
- **Task 6** — `lib/remap.sh` (`remap_json_paths`, `remap_claude_mem`). **Fixed a
  real bug in the original plan's jq expression**: it only rewrote root-level
  object keys, not nested ones, which broke the actual `.claude.json` shape
  (`{"projects": {"<path>": {...}}}` — the path is a *nested* key). Fixed with two
  sequential full `walk()` passes: one rewriting object keys at every depth, one
  rewriting string values. Commit `13ac31f`.
- **Manifest naming** — `lib/manifest.sh` / `tests/manifest.bats` updated from
  `repo`→`repos` to match. Commit `b27f97f`.
- **Task 9b** — `lib/plugins.sh` (`plugins_reinstall`): reads
  `known_marketplaces.json` + `installed_plugins.json`, runs
  `claude plugin marketplace add <owner/repo>` + `claude plugin install
  <name>@<marketplace>`. Verified against this machine's **real** manifests
  (4 plugins: `superpowers@claude-plugins-official`, `claude-mem@thedotmack`,
  `handoff@handoff-marketplace`, `headroom@headroom-marketplace`) — all 4
  reproduced correctly in a dry run. Commit `a4af960`.
- **Task 10** — `backup.sh` orchestrator: Phase 0 git safety → manifest build →
  include/exclude assembly → `archive_pack`. Smoke-tested end-to-end. Commit
  `61928f1`.
- **Task 11 (trimmed)** — `lib/verify.sh` + lean `restore.sh`: extract archive,
  move projects to `$REPO_ROOT` (`~/repos`), remap paths, reinstall plugins,
  print verification report. Requires `claude` already on `PATH` (manual install
  assumption). **Full backup→restore round-trip smoke-tested** (same-`$HOME`
  simulation): project moved, `.claude.json` path correctly rewritten from
  `.../git/p` to `.../repos/p`. Commit `51e1c06`.
- **Task 12 (trimmed)** — full `bats tests/` (26/26 pass) + `shellcheck -x` on
  all scripts (clean). README "Migration to a new machine" section added.
  Commit `ccba5ed`.

All committed tasks pass `bats` + `shellcheck -x`. Working tree still has one
unrelated dirty file `claude/CLAUDE.md` — **do not touch it** (pre-existing, not
part of this work).

## Remaining: the live run (not started)

This is the real payoff and hasn't happened yet:

1. `./backup.sh` on this machine — reviews git state for all 13 repos under
   `~/git` (`adubatec`, `api`, `brain` (non-git), `camunda`,
   `claude-code-toolkit`, `claude-memory`, `dotfiles`, `projeto-publica`,
   `prototipo-tip-cti`, `prototipo-tip-cti_bkp`, `server-test`, `tip`, `web`).
   Approve commit/push **per repo** when prompted — nothing is pushed silently.
   Company remotes (`git.embrapa.io`, `git-cnpmf.nuvem.ti.embrapa.br`) get the
   same treatment, no special-casing needed (git_safety is host-agnostic).
2. Produces `~/dev-env-backup-YYYYMMDD.tar.zst` — plaintext, contains SSH keys +
   API tokens in cleartext. Hand-carry only; wipe after restore.
3. On the new Ubuntu machine (after manually installing Claude Code): clone this
   repo, run `./restore.sh <archive>`.

## Deferred (code exists, not wired into restore.sh)

- claude-mem CA install + connectivity test (`lib/claude_mem.sh` in the plan doc).
- Mimo Code reinstall (`lib/mimo.sh` in the plan doc).
- Runtime installers (`ensure_node/bun/java/dotnet/claude_cli` — plan doc Task 9;
  `ensure_claude_cli` is moot now since Claude Code is installed manually first).

## Known real-world caveat

`remap_json_paths`/`remap_claude_mem` assume `$HOME` is the same string on the old
and new machine (true here: same username `lupontes`, both Ubuntu). If that ever
changes, the recorded absolute paths in `.claude.json` won't match `$HOME/git` at
restore time and the remap will silently no-op (warns, doesn't fail).
