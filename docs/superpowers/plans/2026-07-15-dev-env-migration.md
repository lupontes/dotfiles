# Dev Environment Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the tooling in the `dotfiles` repo that backs up workstation `lupontes` into one plaintext archive and restores it fully onto a fresh Ubuntu Desktop, with projects remapped `~/git`→`~/repo`, Claude Code + plugins + claude-mem (remote, port 443) working, and Mimo Code reinstalled.

**Architecture:** Plain POSIX-ish bash, one orchestrator per direction (`backup.sh`, `restore.sh`) delegating to focused modules in `lib/`. Existing `packages.sh`/`repos.sh` are extended, not duplicated. Every module is sourced (functions, no side effects at load) so it is unit-testable with `bats`. The archive is a **plaintext** `tar.zst` (encryption declined by the user — media is hand-carried); the pack/unpack pipeline checks every stage's exit status so a partial failure never reports success.

**Tech Stack:** bash, `tar`+`zstd` (plaintext archive), `jq` (manifest/JSON edits), `git`, `nvm`/Node, `bun`, `npm` (`@mimo-ai/plugin`), `curl` (claude-mem test), `bats-core` (tests), `shellcheck` (lint).

## Global Constraints

- Projects root: source `~/git`, destination `~/repo`. No script hard-codes a home path other than via `$HOME`.
- Ubuntu release is **never hard-coded**; detect at runtime on the destination.
- All code, identifiers, and comments in **English**. Commit messages: Conventional Commits, imperative, lowercase, no trailing period.
- claude-mem: URL `https://163.176.168.207:443`; reuse API key + `project_id` from backup; CA cert `caddy-root.crt`; **never** mint keys, SSH to the server, or change firewalls.
- claude-mem corpus/path remap: `git` → `repo`.
- Programs come from official sources only — never from the source machine's installed binaries. The backup carries config/data/projects, NOT installed program trees. Excluded from the backup: `.claude/plugins/{cache,marketplaces}`, `.claude/plugins/plugin-catalog-cache.json`, `.mimocode/node_modules`, `.mimocode/package-lock.json`, `.nvm`, `.bun`, `.dotnet`. Kept as the reinstall manifest: `.claude/plugins/{installed_plugins.json,known_marketplaces.json,data/}`.
- Plugins are reinstalled from their GitHub marketplaces via `claude plugin marketplace add <owner/repo>` then `claude plugin install <name>@<marketplace>`.
- Nothing is pushed to any git remote without explicit interactive approval (Phase 0).
- The archive is plaintext (no encryption, per the user's decision). Secrets (`~/.ssh`, API key, `~/.claude.json`) travel inside it; they must never be echoed to logs and never committed to git. The archive file itself is a secret while it exists.
- Every module file has one responsibility; keep files focused and small.
- Commit message trailer for all commits in this plan:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

---

## File Structure

```
dotfiles/
  backup.sh                 # NEW  orchestrator (source machine)
  restore.sh                # NEW  orchestrator (destination, idempotent)
  repos.sh                  # MODIFY  parameterize REPO_ROOT (~/git -> ~/repo)
  packages.sh               # MODIFY  add runtime/prereq installers
  lib/
    common.sh               # NEW  log/die/confirm helpers, strict mode
    manifest.sh             # NEW  build/read manifest.json
    git_safety.sh           # NEW  Phase 0 report + interactive commit/push
    archive.sh              # NEW  tar+zstd plaintext pack/unpack (pipeline-failure detection)
    remap.sh                # NEW  ~/git -> ~/repo path remap across configs
    claude_mem.sh           # NEW  restore config + connectivity test
    plugins.sh              # NEW  reinstall Claude Code plugins from GitHub marketplaces
    mimo.sh                 # NEW  reinstall @mimo-ai/plugin + customizations
    verify.sh               # NEW  final verification report
  tests/
    test_helper.bash        # NEW  shared bats setup (tmp HOME sandbox)
    common.bats
    manifest.bats
    git_safety.bats
    archive.bats
    remap.bats
    claude_mem.bats
    plugins.bats
    mimo.bats
    verify.bats
```

---

### Task 1: Test harness, lint, and `lib/common.sh`

**Files:**
- Create: `lib/common.sh`
- Create: `tests/test_helper.bash`
- Create: `tests/common.bats`
- Modify: `packages.sh` (add `bats`, `shellcheck`, `age`, `zstd`, `jq` to dev tools)

**Interfaces:**
- Produces: `log(msg)`, `warn(msg)`, `die(msg)` (exit 1), `confirm(prompt)` (returns 0 on yes),
  `require_cmd(name...)`; all defined in `lib/common.sh`. Sourcing the file must have **no** side effects beyond defining functions and setting `set -euo pipefail` only when `COMMON_STRICT=1`.

- [ ] **Step 1: Write the failing test**

`tests/test_helper.bash`:
```bash
# Shared bats helpers: run each test in an isolated fake HOME.
setup_sandbox() {
  export REPO_ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  export OLD_HOME_UNUSED=1
}
teardown_sandbox() { [ -n "${TEST_HOME:-}" ] && rm -rf "$TEST_HOME"; }
```

`tests/common.bats`:
```bash
load test_helper
setup()    { setup_sandbox; source "$REPO_ROOT_DIR/lib/common.sh"; }
teardown() { teardown_sandbox; }

@test "confirm returns 0 on y" {
  run bash -c 'source "'"$REPO_ROOT_DIR"'/lib/common.sh"; printf "y\n" | confirm "ok?"'
  [ "$status" -eq 0 ]
}
@test "confirm returns 1 on n" {
  run bash -c 'source "'"$REPO_ROOT_DIR"'/lib/common.sh"; printf "n\n" | confirm "ok?"'
  [ "$status" -eq 1 ]
}
@test "die exits non-zero and prints message" {
  run bash -c 'source "'"$REPO_ROOT_DIR"'/lib/common.sh"; die "boom"'
  [ "$status" -eq 1 ]
  [[ "$output" == *"boom"* ]]
}
@test "require_cmd fails for a missing binary" {
  run bash -c 'source "'"$REPO_ROOT_DIR"'/lib/common.sh"; require_cmd definitely_not_a_real_cmd_xyz'
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/common.bats`
Expected: FAIL — `lib/common.sh` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

`lib/common.sh`:
```bash
#!/usr/bin/env bash
# Shared helpers. Sourcing defines functions only (no side effects).
[ -n "${COMMON_STRICT:-}" ] && set -euo pipefail

log()  { printf '[*] %s\n' "$*" >&2; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

# confirm PROMPT -> reads one line from stdin; 0 for y/Y/yes, else 1.
confirm() {
  local reply
  printf '%s [y/N] ' "$1" >&2
  read -r reply || return 1
  case "$reply" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# require_cmd NAME... -> die on first missing command.
require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "required command not found: $c"
  done
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats tests/common.bats && shellcheck lib/common.sh`
Expected: PASS; shellcheck clean.

- [ ] **Step 5: Add dev prerequisites to `packages.sh`**

In `packages.sh`, add to the apt package list (near the existing package installs):
```bash
# Migration tooling prerequisites
apt_pkgs+=(age zstd jq bats shellcheck)
```
(If `packages.sh` uses a different variable name than `apt_pkgs`, append these to that list instead — keep the existing pattern.)

- [ ] **Step 6: Commit**

```bash
git add lib/common.sh tests/test_helper.bash tests/common.bats packages.sh
git commit -m "feat(migration): add test harness and common shell helpers"
```

---

### Task 2: `lib/manifest.sh` — build and read the manifest

**Files:**
- Create: `lib/manifest.sh`
- Create: `tests/manifest.bats`

**Interfaces:**
- Consumes: `lib/common.sh`.
- Produces:
  - `manifest_build > FILE` — writes JSON to stdout with keys: `created`, `source_home`,
    `projects_src` (`"git"`), `projects_dst` (`"repo"`), `versions` (node, bun, java, dotnet, npm),
    `claude_mem` (`url`, `project_id`, `corpus_remap` = `{"git":"repo"}`), `apt_packages` (array).
  - `manifest_get FILE KEYPATH` — echoes a value via `jq` (e.g. `.claude_mem.project_id`).

- [ ] **Step 1: Write the failing test**

`tests/manifest.bats`:
```bash
load test_helper
setup()    { setup_sandbox
             source "$REPO_ROOT_DIR/lib/common.sh"
             source "$REPO_ROOT_DIR/lib/manifest.sh"
             mkdir -p "$HOME/.claude"
             cat > "$HOME/.claude/settings.json" <<'JSON'
{ "env": {
  "CLAUDE_MEM_SERVER_BETA_URL": "https://163.176.168.207:443",
  "CLAUDE_MEM_SERVER_BETA_PROJECT_ID": "48e2759b-2cd3-4336-9601-3b3dce28b957" } }
JSON
           }
teardown() { teardown_sandbox; }

@test "manifest_build emits valid json with the project remap" {
  manifest_build > "$HOME/m.json"
  run jq -e '.projects_src=="git" and .projects_dst=="repo"' "$HOME/m.json"
  [ "$status" -eq 0 ]
}
@test "manifest carries claude-mem url and project id from settings" {
  manifest_build > "$HOME/m.json"
  [ "$(manifest_get "$HOME/m.json" '.claude_mem.url')" = "https://163.176.168.207:443" ]
  [ "$(manifest_get "$HOME/m.json" '.claude_mem.project_id')" = "48e2759b-2cd3-4336-9601-3b3dce28b957" ]
}
@test "manifest corpus remap maps git to repo" {
  manifest_build > "$HOME/m.json"
  [ "$(manifest_get "$HOME/m.json" '.claude_mem.corpus_remap.git')" = "repo" ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/manifest.bats`
Expected: FAIL — `lib/manifest.sh` missing.

- [ ] **Step 3: Write minimal implementation**

`lib/manifest.sh`:
```bash
#!/usr/bin/env bash
# Build/read the migration manifest. Requires common.sh sourced first.

_ver() { command -v "$1" >/dev/null 2>&1 && "$@" 2>/dev/null | head -n1 || echo ""; }

manifest_build() {
  local settings="$HOME/.claude/settings.json"
  local url="" pid=""
  if [ -f "$settings" ]; then
    url=$(jq -r '.env.CLAUDE_MEM_SERVER_BETA_URL // ""' "$settings")
    pid=$(jq -r '.env.CLAUDE_MEM_SERVER_BETA_PROJECT_ID // ""' "$settings")
  fi
  jq -n \
    --arg created "$(date -Iseconds)" \
    --arg home "$HOME" \
    --arg node "$(_ver node --version)" \
    --arg bun "$(_ver bun --version)" \
    --arg java "$(_ver java -version 2>&1)" \
    --arg dotnet "$(_ver dotnet --version)" \
    --arg npm "$(_ver npm --version)" \
    --arg url "$url" \
    --arg pid "$pid" \
    '{
      created: $created,
      source_home: $home,
      projects_src: "git",
      projects_dst: "repo",
      versions: { node:$node, bun:$bun, java:$java, dotnet:$dotnet, npm:$npm },
      claude_mem: { url:$url, project_id:$pid, corpus_remap: { "git":"repo" } },
      apt_packages: []
    }'
}

manifest_get() { jq -r "$2" "$1"; }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats tests/manifest.bats && shellcheck lib/manifest.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/manifest.sh tests/manifest.bats
git commit -m "feat(migration): add manifest builder and reader"
```

---

### Task 3: `lib/git_safety.sh` — Phase 0 report + interactive commit/push

**Files:**
- Create: `lib/git_safety.sh`
- Create: `tests/git_safety.bats`

**Interfaces:**
- Consumes: `lib/common.sh`.
- Produces:
  - `git_repo_state DIR` — echoes `TAB`-separated: `branch  dirty_count  ahead_count  has_upstream(0/1)  is_submodule_parent(0/1)`.
  - `git_scan_root ROOT` — for each child dir, echoes one line: `name  <state>` (`NOT_GIT` when no `.git`).
  - `git_safety_report ROOT` — prints a human report; exit 0 always.
  - `git_needs_action STATE` — returns 0 if the state line implies dirty>0, ahead>0, or missing upstream.

  Interactive commit/push is a thin wrapper (`git_safety_interactive ROOT`) that, per repo needing action, shows `git -C DIR status`/`diff`, calls `confirm` before `git commit` and again before `git push`. It is exercised live, not in unit tests (its pure helpers above are the tested surface).

- [ ] **Step 1: Write the failing test**

`tests/git_safety.bats`:
```bash
load test_helper
setup()    { setup_sandbox
             source "$REPO_ROOT_DIR/lib/common.sh"
             source "$REPO_ROOT_DIR/lib/git_safety.sh"
             export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t
             export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
             mkdir -p "$HOME/root"; }
teardown() { teardown_sandbox; }

mk_repo() { git init -q "$1"; ( cd "$1" && echo a > a.txt && git add a.txt \
            && git commit -qm init ); }

@test "clean repo reports dirty=0 and needs no action" {
  mk_repo "$HOME/root/clean"
  state=$(git_repo_state "$HOME/root/clean")
  dirty=$(echo "$state" | cut -f2)
  [ "$dirty" -eq 0 ]
  run git_needs_action "$state"
  [ "$status" -ne 0 ]
}
@test "dirty repo is detected and needs action" {
  mk_repo "$HOME/root/dirty"; echo b >> "$HOME/root/dirty/a.txt"
  state=$(git_repo_state "$HOME/root/dirty")
  [ "$(echo "$state" | cut -f2)" -eq 1 ]
  run git_needs_action "$state"
  [ "$status" -eq 0 ]
}
@test "non-git dir is reported NOT_GIT by the scan" {
  mkdir -p "$HOME/root/plain"
  run git_scan_root "$HOME/root"
  [[ "$output" == *"plain	NOT_GIT"* ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/git_safety.bats`
Expected: FAIL — module missing.

- [ ] **Step 3: Write minimal implementation**

`lib/git_safety.sh`:
```bash
#!/usr/bin/env bash
# Phase 0: report git state and drive interactive commit/push. Needs common.sh.

git_repo_state() {
  local dir="$1"
  local branch dirty ahead upstream=0 sub=0
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
  dirty=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if git -C "$dir" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    upstream=1
    ahead=$(git -C "$dir" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
  else
    ahead=0
  fi
  [ -f "$dir/.gitmodules" ] && sub=1
  printf '%s\t%s\t%s\t%s\t%s\n' "$branch" "$dirty" "$ahead" "$upstream" "$sub"
}

git_scan_root() {
  local root="$1" d name
  for d in "$root"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    if [ -d "$d/.git" ]; then
      printf '%s\t%s\n' "$name" "$(git_repo_state "$d")"
    else
      printf '%s\tNOT_GIT\n' "$name"
    fi
  done
}

# 0 (needs action) if dirty>0 OR ahead>0 OR no upstream.
git_needs_action() {
  local state="$1"
  [ "$state" = "NOT_GIT" ] && return 1
  local dirty ahead upstream
  dirty=$(echo "$state" | cut -f2)
  ahead=$(echo "$state" | cut -f3)
  upstream=$(echo "$state" | cut -f4)
  { [ "${dirty:-0}" -gt 0 ] || [ "${ahead:-0}" -gt 0 ] || [ "${upstream:-1}" -eq 0 ]; }
}

git_safety_report() {
  local root="$1" line name state
  log "Git safety report for $root"
  while IFS= read -r line; do
    name=$(echo "$line" | cut -f1)
    state=$(echo "$line" | cut -f2-)
    if [ "$state" = "NOT_GIT" ]; then
      printf '  %-24s NOT_GIT (archive-only)\n' "$name" >&2
    elif git_needs_action "$state"; then
      printf '  %-24s NEEDS ACTION  %s\n' "$name" "$state" >&2
    else
      printf '  %-24s clean & synced\n' "$name" >&2
    fi
  done < <(git_scan_root "$root")
}

# Interactive; exercised live, not in unit tests.
git_safety_interactive() {
  local root="$1" line name dir state msg
  while IFS= read -r line; do
    name=$(echo "$line" | cut -f1); state=$(echo "$line" | cut -f2-)
    dir="$root/$name"
    [ "$state" = "NOT_GIT" ] && continue
    git_needs_action "$state" || continue
    log "== $name =="; git -C "$dir" status -s >&2; git -C "$dir" --no-pager diff --stat >&2
    if confirm "commit changes in $name?"; then
      printf 'Conventional Commit message: ' >&2; read -r msg
      git -C "$dir" add -A && git -C "$dir" commit -qm "$msg"
    fi
    if confirm "push $name to its remote?"; then
      if git -C "$dir" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
        git -C "$dir" push
      else
        git -C "$dir" push -u origin "$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
      fi
    fi
  done < <(git_scan_root "$root")
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats tests/git_safety.bats && shellcheck lib/git_safety.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/git_safety.sh tests/git_safety.bats
git commit -m "feat(migration): add git safety report and interactive commit/push"
```

---

### Task 4: `lib/archive.sh` — plaintext pack/unpack with pipeline-failure detection

**Files:**
- Create: `lib/archive.sh`
- Create: `tests/archive.bats`

**Interfaces:**
- Consumes: `lib/common.sh`.
- Produces:
  - `archive_pack SRC_LIST_FILE OUT_PATH` — reads newline-separated paths (relative to `$HOME`) from `SRC_LIST_FILE`, creates a plaintext `tar | zstd` archive; `die`s if any pipeline stage fails. Honors optional env `ARCHIVE_EXCLUDE_FILE` (a file of tar `--exclude-from` patterns) so installed program trees can be omitted.
  - `archive_unpack IN_PATH DEST_HOME` — `zstd -d | tar -x` into `DEST_HOME`; `die`s if any stage fails.
  - `archive_list IN_PATH` — lists entries (no extraction).
- No encryption: the archive is a plaintext `tar.zst` (encryption declined by the user; media is hand-carried). Every pipeline uses `PIPESTATUS` so a partial/failed run never reports success.

- [ ] **Step 1: Write the failing test**

`tests/archive.bats`:
```bash
load test_helper
setup() { setup_sandbox
          source "$REPO_ROOT_DIR/lib/common.sh"
          source "$REPO_ROOT_DIR/lib/archive.sh"
          mkdir -p "$HOME/.claude" "$HOME/git/proj"
          echo settings > "$HOME/.claude/s.json"
          echo code     > "$HOME/git/proj/main.c"
          printf '.claude\ngit\n' > "$HOME/list.txt"; }
teardown() { teardown_sandbox; }

@test "pack then list shows archived paths" {
  archive_pack "$HOME/list.txt" "$HOME/out.tar.zst"
  [ -f "$HOME/out.tar.zst" ]
  run archive_list "$HOME/out.tar.zst"
  [[ "$output" == *".claude/s.json"* ]]
  [[ "$output" == *"git/proj/main.c"* ]]
}
@test "unpack restores file contents into a new home" {
  archive_pack "$HOME/list.txt" "$HOME/out.tar.zst"
  mkdir -p "$HOME/dest"
  archive_unpack "$HOME/out.tar.zst" "$HOME/dest"
  [ "$(cat "$HOME/dest/git/proj/main.c")" = "code" ]
}
@test "pack fails when a listed source path is missing" {
  printf '.claude\nnope-missing\n' > "$HOME/bad.txt"
  run archive_pack "$HOME/bad.txt" "$HOME/out.tar.zst"
  [ "$status" -ne 0 ]
}
@test "unpack fails on a corrupt archive" {
  echo "not a zst stream" > "$HOME/corrupt.tar.zst"
  mkdir -p "$HOME/dest"
  run archive_unpack "$HOME/corrupt.tar.zst" "$HOME/dest"
  [ "$status" -ne 0 ]
}
@test "ARCHIVE_EXCLUDE_FILE omits matched paths" {
  mkdir -p "$HOME/git/proj/node_modules"
  echo junk > "$HOME/git/proj/node_modules/x.js"
  printf '*/node_modules/*\n' > "$HOME/excl.txt"
  ARCHIVE_EXCLUDE_FILE="$HOME/excl.txt" archive_pack "$HOME/list.txt" "$HOME/out.tar.zst"
  run archive_list "$HOME/out.tar.zst"
  [[ "$output" == *"git/proj/main.c"* ]]
  [[ "$output" != *"node_modules"* ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/archive.bats`
Expected: FAIL — module missing.

- [ ] **Step 3: Write minimal implementation**

`lib/archive.sh`:
```bash
#!/usr/bin/env bash
# Plaintext archive pack/unpack. Needs common.sh. Requires tar, zstd.

archive_pack() {
  local list="$1" out="$2"
  require_cmd tar zstd
  # Optional exclude patterns (installed program trees) via ARCHIVE_EXCLUDE_FILE.
  local exargs=()
  [ -n "${ARCHIVE_EXCLUDE_FILE:-}" ] && exargs=(--exclude-from="$ARCHIVE_EXCLUDE_FILE")
  # -C $HOME so archived paths are relative to home; --files-from for the include list.
  tar -C "$HOME" "${exargs[@]}" -cf - --files-from="$list" | zstd -q -19 -T0 > "$out"
  local st=("${PIPESTATUS[@]}")
  [ "${st[0]}" -eq 0 ] || die "tar failed (${st[0]})"
  [ "${st[1]}" -eq 0 ] || die "zstd failed (${st[1]})"
  [ -s "$out" ] || die "archive is empty: $out"
  log "archive written: $out"
}

archive_unpack() {
  local in="$1" dest="$2"
  require_cmd tar zstd
  mkdir -p "$dest"
  zstd -d -q < "$in" | tar -C "$dest" -xf -
  local st=("${PIPESTATUS[@]}")
  [ "${st[0]}" -eq 0 ] || die "zstd decompress failed (${st[0]})"
  [ "${st[1]}" -eq 0 ] || die "tar extract failed (${st[1]})"
  log "archive extracted into: $dest"
}

archive_list() {
  local in="$1"
  require_cmd tar zstd
  zstd -d -q < "$in" | tar -tf -
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats tests/archive.bats && shellcheck lib/archive.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/archive.sh tests/archive.bats
git commit -m "feat(migration): add plaintext tar/zstd archive module"
```

---

### Task 5: Parameterize `repos.sh` for `REPO_ROOT`

**Files:**
- Modify: `repos.sh`
- Create: `tests/repos.bats`

**Interfaces:**
- Produces: `repos.sh` honors env `REPO_ROOT` (default `$HOME/repo`) for the clone/target
  directory instead of a hard-coded `~/git`.

- [ ] **Step 1: Read the current file**

Run: `cat repos.sh` — locate the hard-coded destination (currently `~/git` / `$HOME/git`).

- [ ] **Step 2: Write the failing test**

`tests/repos.bats`:
```bash
load test_helper
setup()    { setup_sandbox; }
teardown() { teardown_sandbox; }

@test "repos.sh references REPO_ROOT and defaults to repo" {
  run grep -E 'REPO_ROOT' "$REPO_ROOT_DIR/repos.sh"
  [ "$status" -eq 0 ]
  run grep -E 'REPO_ROOT:-\$\{?HOME\}?/repo|HOME/repo' "$REPO_ROOT_DIR/repos.sh"
  [ "$status" -eq 0 ]
}
@test "repos.sh no longer hard-codes ~/git as the destination root" {
  run grep -E '(^|[^A-Za-z_])\$HOME/git($|[^A-Za-z_])' "$REPO_ROOT_DIR/repos.sh"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bats tests/repos.bats`
Expected: FAIL — destination still hard-coded.

- [ ] **Step 4: Edit `repos.sh`**

At the top of `repos.sh`, add the parameter and replace destination references:
```bash
# Destination root for cloned projects (source machine used ~/git).
REPO_ROOT="${REPO_ROOT:-$HOME/repo}"
mkdir -p "$REPO_ROOT"
```
Replace each hard-coded `$HOME/git` / `~/git` destination with `"$REPO_ROOT"`.

- [ ] **Step 5: Run test to verify it passes**

Run: `bats tests/repos.bats && shellcheck repos.sh`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add repos.sh tests/repos.bats
git commit -m "refactor(migration): parameterize repos.sh destination as REPO_ROOT"
```

---

### Task 6: `lib/remap.sh` — remap `~/git` → `~/repo` across configs

**Files:**
- Create: `lib/remap.sh`
- Create: `tests/remap.bats`

**Interfaces:**
- Consumes: `lib/common.sh`.
- Produces:
  - `remap_json_paths FILE OLD NEW` — rewrites every string value containing `OLD` to use `NEW`
    (used for `~/.claude.json`, which is keyed by project path).
  - `remap_claude_mem OLD NEW` — updates claude-mem so memory follows the new path: rewrites
    stored cwd references and applies the corpus rename `git`→`repo`. Implemented by (a) JSON path
    rewrite of `~/.claude-mem/settings.json`, and (b) writing a marker
    `~/.claude-mem/.cwd-remap-<old>-to-<new>` consumed by claude-mem on next start (mirrors the
    existing `.cwd-remap-applied-v1` mechanism).

- [ ] **Step 1: Write the failing test**

`tests/remap.bats`:
```bash
load test_helper
setup()    { setup_sandbox
             source "$REPO_ROOT_DIR/lib/common.sh"
             source "$REPO_ROOT_DIR/lib/remap.sh"; }
teardown() { teardown_sandbox; }

@test "remap_json_paths rewrites home/git to home/repo in string values" {
  printf '{"projects":{"%s/git/api":{"x":1}}}' "$HOME" > "$HOME/.claude.json"
  remap_json_paths "$HOME/.claude.json" "$HOME/git" "$HOME/repo"
  run jq -e --arg p "$HOME/repo/api" '.projects | has($p)' "$HOME/.claude.json"
  [ "$status" -eq 0 ]
}
@test "remap_claude_mem writes the cwd-remap marker" {
  mkdir -p "$HOME/.claude-mem"; echo '{}' > "$HOME/.claude-mem/settings.json"
  remap_claude_mem "$HOME/git" "$HOME/repo"
  run bash -c 'ls "$HOME/.claude-mem/".cwd-remap-*-to-* 2>/dev/null'
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/remap.bats`
Expected: FAIL — module missing.

- [ ] **Step 3: Write minimal implementation**

`lib/remap.sh`:
```bash
#!/usr/bin/env bash
# Remap source project paths to destination paths across configs. Needs common.sh.

# Rewrite every string value containing OLD to use NEW (keys included, since
# .claude.json keys projects by absolute path). Uses jq walk for safety.
remap_json_paths() {
  local file="$1" old="$2" new="$3" tmp
  [ -f "$file" ] || { warn "remap_json_paths: no file $file"; return 0; }
  tmp="$(mktemp)"
  jq --arg old "$old" --arg new "$new" '
    walk(if type=="string" then gsub($old; $new) else . end)
    | if type=="object"
      then with_entries(.key |= gsub($old; $new))
      else . end
  ' "$file" > "$tmp" && mv "$tmp" "$file"
  log "remapped paths in $file"
}

# Make claude-mem memory follow the new project path.
remap_claude_mem() {
  local old="$1" new="$2"
  local dir="$HOME/.claude-mem"
  [ -d "$dir" ] || { warn "no ~/.claude-mem to remap"; return 0; }
  [ -f "$dir/settings.json" ] && remap_json_paths "$dir/settings.json" "$old" "$new"
  # Marker consumed by claude-mem on next start (mirrors .cwd-remap-applied-v1).
  local tag; tag="$(basename "$old")-to-$(basename "$new")"
  printf '{"from":"%s","to":"%s","corpus_remap":{"git":"repo"}}\n' "$old" "$new" \
    > "$dir/.cwd-remap-$tag"
  log "claude-mem cwd remap marker written ($tag)"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats tests/remap.bats && shellcheck lib/remap.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/remap.sh tests/remap.bats
git commit -m "feat(migration): add path remap for claude config and claude-mem"
```

---

### Task 7: `lib/claude_mem.sh` — restore config + connectivity test

**Files:**
- Create: `lib/claude_mem.sh`
- Create: `tests/claude_mem.bats`

**Interfaces:**
- Consumes: `lib/common.sh`.
- Produces:
  - `claude_mem_install_ca CERT_PATH` — copies the Caddy CA into
    `/usr/local/share/ca-certificates/claude-mem-ca.crt` and runs `update-ca-certificates`
    (skipped with a warning when not root / no `update-ca-certificates`).
  - `claude_mem_test URL CERT API_KEY` — TCP-checks the URL host:port, then
    `curl --cacert CERT -H "Authorization: Bearer API_KEY" URL`; returns 0 when the HTTP status is
    one of `200/401/503` (server reachable + TLS valid; `503` is the expected viewer response),
    non-zero otherwise. The `curl` binary is injectable via `CLAUDE_MEM_CURL` for tests.

- [ ] **Step 1: Write the failing test**

`tests/claude_mem.bats`:
```bash
load test_helper
setup()    { setup_sandbox
             source "$REPO_ROOT_DIR/lib/common.sh"
             source "$REPO_ROOT_DIR/lib/claude_mem.sh"
             # fake curl that prints a chosen HTTP status
             cat > "$HOME/fakecurl" <<'SH'
#!/usr/bin/env bash
echo "HTTP_STATUS:${FAKE_STATUS:-503}"
SH
             chmod +x "$HOME/fakecurl"
             export CLAUDE_MEM_CURL="$HOME/fakecurl"
             # bypass the raw TCP check in unit tests
             export CLAUDE_MEM_SKIP_TCP=1; }
teardown() { teardown_sandbox; }

@test "test passes on 503 (expected viewer response)" {
  FAKE_STATUS=503 run claude_mem_test "https://h:443/" "/dev/null" "k"
  [ "$status" -eq 0 ]
}
@test "test passes on 200" {
  FAKE_STATUS=200 run claude_mem_test "https://h:443/" "/dev/null" "k"
  [ "$status" -eq 0 ]
}
@test "test fails on 000 (unreachable)" {
  FAKE_STATUS=000 run claude_mem_test "https://h:443/" "/dev/null" "k"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/claude_mem.bats`
Expected: FAIL — module missing.

- [ ] **Step 3: Write minimal implementation**

`lib/claude_mem.sh`:
```bash
#!/usr/bin/env bash
# claude-mem restore helpers. Needs common.sh.

claude_mem_install_ca() {
  local cert="$1"
  [ -f "$cert" ] || { warn "no CA cert at $cert"; return 0; }
  if command -v update-ca-certificates >/dev/null 2>&1 && [ "$(id -u)" -eq 0 ]; then
    cp "$cert" /usr/local/share/ca-certificates/claude-mem-ca.crt
    update-ca-certificates >/dev/null
    log "claude-mem CA installed into system trust store"
  else
    warn "skipping system CA install (needs root); NODE_EXTRA_CA_CERTS still covers Node"
  fi
}

# 0 if reachable + TLS valid (HTTP 200/401/503), else non-zero.
claude_mem_test() {
  local url="$1" cert="$2" key="$3"
  local curl_bin="${CLAUDE_MEM_CURL:-curl}"
  if [ -z "${CLAUDE_MEM_SKIP_TCP:-}" ]; then
    local hostport="${url#https://}"; hostport="${hostport%%/*}"
    local host="${hostport%%:*}" port="${hostport##*:}"
    [ "$host" = "$port" ] && port=443
    timeout 6 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null \
      || { warn "TCP $host:$port unreachable"; return 1; }
  fi
  local out status
  out=$("$curl_bin" -s --cacert "$cert" -H "Authorization: Bearer $key" \
        --max-time 8 "$url" -w '\nHTTP_STATUS:%{http_code}\n' 2>/dev/null)
  status=$(printf '%s\n' "$out" | sed -n 's/^HTTP_STATUS://p' | tail -n1)
  case "$status" in
    200|401|503) log "claude-mem reachable (HTTP $status)"; return 0 ;;
    *) warn "claude-mem test failed (HTTP ${status:-none})"; return 1 ;;
  esac
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats tests/claude_mem.bats && shellcheck lib/claude_mem.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/claude_mem.sh tests/claude_mem.bats
git commit -m "feat(migration): add claude-mem CA install and connectivity test"
```

---

### Task 8: `lib/mimo.sh` — reinstall Mimo Code

**Files:**
- Create: `lib/mimo.sh`
- Create: `tests/mimo.bats`

**Interfaces:**
- Consumes: `lib/common.sh`.
- Produces:
  - `mimo_reinstall VERSION` — ensures `~/.mimocode/package.json` pins `@mimo-ai/plugin@VERSION`,
    runs `npm install` there, and restores custom `command/` and `skills/` if present in a staged
    restore dir (`$MIMO_STAGE`). `npm` is injectable via `MIMO_NPM` for tests.
  - `mimo_verify` — returns 0 if `~/.mimocode/bin/mimo` exists and is executable.

- [ ] **Step 1: Write the failing test**

`tests/mimo.bats`:
```bash
load test_helper
setup()    { setup_sandbox
             source "$REPO_ROOT_DIR/lib/common.sh"
             source "$REPO_ROOT_DIR/lib/mimo.sh"
             # fake npm that just creates the launcher to prove it ran
             cat > "$HOME/fakenpm" <<'SH'
#!/usr/bin/env bash
mkdir -p "$PWD/bin"; printf '#!/bin/sh\necho mimo\n' > "$PWD/bin/mimo"
chmod +x "$PWD/bin/mimo"
SH
             chmod +x "$HOME/fakenpm"
             export MIMO_NPM="$HOME/fakenpm"; }
teardown() { teardown_sandbox; }

@test "reinstall pins the version in package.json" {
  mimo_reinstall "0.1.4"
  run jq -e '.dependencies["@mimo-ai/plugin"]=="0.1.4"' "$HOME/.mimocode/package.json"
  [ "$status" -eq 0 ]
}
@test "verify passes once the launcher exists" {
  mimo_reinstall "0.1.4"
  run mimo_verify
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/mimo.bats`
Expected: FAIL — module missing.

- [ ] **Step 3: Write minimal implementation**

`lib/mimo.sh`:
```bash
#!/usr/bin/env bash
# Reinstall the Mimo Code AI (@mimo-ai/plugin). Needs common.sh.

mimo_reinstall() {
  local version="$1"
  local dir="$HOME/.mimocode"
  local npm_bin="${MIMO_NPM:-npm}"
  mkdir -p "$dir"
  jq -n --arg v "$version" \
    '{name:".mimocode", dependencies:{"@mimo-ai/plugin":$v}}' \
    > "$dir/package.json"
  ( cd "$dir" && "$npm_bin" install ) || die "mimo npm install failed"
  # Restore custom command/ and skills/ from the staged restore, if present.
  if [ -n "${MIMO_STAGE:-}" ]; then
    [ -d "$MIMO_STAGE/command" ] && cp -a "$MIMO_STAGE/command" "$dir/"
    [ -d "$MIMO_STAGE/skills" ]  && cp -a "$MIMO_STAGE/skills"  "$dir/"
  fi
  log "mimo reinstalled (@mimo-ai/plugin@$version)"
}

mimo_verify() {
  [ -x "$HOME/.mimocode/bin/mimo" ] || { warn "mimo launcher missing"; return 1; }
  log "mimo launcher present"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats tests/mimo.bats && shellcheck lib/mimo.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/mimo.sh tests/mimo.bats
git commit -m "feat(migration): add mimo code reinstall module"
```

---

### Task 9: Runtime installers in `packages.sh`

**Files:**
- Modify: `packages.sh`

**Interfaces:**
- Produces: idempotent functions `ensure_node`, `ensure_bun`, `ensure_java`, `ensure_dotnet`,
  `ensure_claude_cli` — each checks for the tool and installs it only when absent. Callable from
  `restore.sh`.

- [ ] **Step 1: Read the current file**

Run: `cat packages.sh` — note the existing structure and any apt helper it already defines.

- [ ] **Step 2: Add idempotent installers**

Append to `packages.sh` (adapt to the file's existing helpers; do not duplicate apt logic):
```bash
ensure_node() {   # nvm + LTS (destination resolves the current LTS)
  command -v node >/dev/null 2>&1 && return 0
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] || {
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  }
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"; nvm install --lts
}
ensure_bun() {
  command -v bun >/dev/null 2>&1 && return 0
  curl -fsSL https://bun.sh/install | bash
}
ensure_java() {
  command -v java >/dev/null 2>&1 && return 0
  sudo apt-get install -y default-jdk maven
}
ensure_dotnet() {
  command -v dotnet >/dev/null 2>&1 && return 0
  sudo apt-get install -y dotnet-sdk-8.0 || warn "dotnet SDK not installed (adjust version)"
}
ensure_claude_cli() {
  command -v claude >/dev/null 2>&1 && return 0
  curl -fsSL https://claude.ai/install.sh | bash
}
```

- [ ] **Step 3: Guard the script so it is safe to `source`**

`restore.sh` sources `packages.sh` for its `ensure_*` functions, so the file must not
run installs at load time. Wrap any existing top-level install commands (not the function
definitions) in a run-only-when-executed guard:
```bash
# Only run the install flow when executed directly, not when sourced for its functions.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  # ... existing top-level package-install calls stay here ...
fi
```

- [ ] **Step 4: Lint**

Run: `shellcheck packages.sh`
Expected: clean (module-level `source`/`. nvm.sh` disables noted inline).

- [ ] **Step 5: Commit**

```bash
git add packages.sh
git commit -m "feat(migration): add idempotent runtime installers to packages.sh"
```

---

### Task 9b: `lib/plugins.sh` — reinstall Claude Code plugins from official marketplaces

**Files:**
- Create: `lib/plugins.sh`
- Create: `tests/plugins.bats`

**Interfaces:**
- Consumes: `lib/common.sh`.
- Produces:
  - `plugins_reinstall MANIFEST_DIR` — reads `MANIFEST_DIR/known_marketplaces.json` and
    `MANIFEST_DIR/installed_plugins.json` (the small manifests kept in the backup), then for
    each marketplace runs `claude plugin marketplace add <owner/repo>` and for each plugin
    runs `claude plugin install <name>@<marketplace>`. The `claude` binary is injectable via
    `CLAUDE_BIN` for tests. Missing manifests → warn and return 0 (nothing to reinstall).

- [ ] **Step 1: Write the failing test**

`tests/plugins.bats`:
```bash
load test_helper
setup()    { setup_sandbox
             source "$REPO_ROOT_DIR/lib/common.sh"
             source "$REPO_ROOT_DIR/lib/plugins.sh"
             mkdir -p "$HOME/man"
             cat > "$HOME/man/known_marketplaces.json" <<'JSON'
{ "claude-plugins-official": { "source": { "source": "github", "repo": "anthropics/claude-plugins-official" } },
  "thedotmack": { "source": { "source": "github", "repo": "thedotmack/claude-mem" } } }
JSON
             cat > "$HOME/man/installed_plugins.json" <<'JSON'
{ "version": 2, "plugins": {
  "superpowers@claude-plugins-official": [ { "version": "6.1.1" } ],
  "claude-mem@thedotmack": [ { "version": "13.11.0" } ] } }
JSON
             cat > "$HOME/fakeclaude" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_LOG"
SH
             chmod +x "$HOME/fakeclaude"
             export CLAUDE_BIN="$HOME/fakeclaude"
             export FAKE_LOG="$HOME/claude.log"; }
teardown() { teardown_sandbox; }

@test "adds each marketplace from its github repo" {
  plugins_reinstall "$HOME/man"
  run cat "$HOME/claude.log"
  [[ "$output" == *"plugin marketplace add anthropics/claude-plugins-official"* ]]
  [[ "$output" == *"plugin marketplace add thedotmack/claude-mem"* ]]
}
@test "installs each plugin by name@marketplace" {
  plugins_reinstall "$HOME/man"
  run cat "$HOME/claude.log"
  [[ "$output" == *"plugin install superpowers@claude-plugins-official"* ]]
  [[ "$output" == *"plugin install claude-mem@thedotmack"* ]]
}
@test "missing manifest returns 0 without calling claude" {
  rm -f "$HOME/man/installed_plugins.json"
  run plugins_reinstall "$HOME/man"
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/claude.log" ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/plugins.bats`
Expected: FAIL — module missing.

- [ ] **Step 3: Write minimal implementation**

`lib/plugins.sh`:
```bash
#!/usr/bin/env bash
# Reinstall Claude Code plugins from their official GitHub marketplaces. Needs common.sh.

plugins_reinstall() {
  local dir="$1"
  local claude_bin="${CLAUDE_BIN:-claude}"
  local mk="$dir/known_marketplaces.json"
  local ip="$dir/installed_plugins.json"
  [ -f "$mk" ] || { warn "no known_marketplaces.json in $dir"; return 0; }
  [ -f "$ip" ] || { warn "no installed_plugins.json in $dir"; return 0; }
  local repo name
  # Add each marketplace from its GitHub source repo (owner/repo).
  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    "$claude_bin" plugin marketplace add "$repo" || warn "marketplace add failed: $repo"
  done < <(jq -r '.[].source | select(.source=="github") | .repo // empty' "$mk")
  # Install each plugin, keyed as name@marketplace.
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    "$claude_bin" plugin install "$name" || warn "plugin install failed: $name"
  done < <(jq -r '.plugins | keys[]' "$ip")
  log "plugins reinstalled from official marketplaces"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats tests/plugins.bats && shellcheck lib/plugins.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/plugins.sh tests/plugins.bats
git commit -m "feat(migration): add plugin reinstall from official marketplaces"
```

---

### Task 10: `backup.sh` orchestrator

**Files:**
- Create: `backup.sh`

**Interfaces:**
- Consumes: `lib/common.sh`, `lib/manifest.sh`, `lib/git_safety.sh`, `lib/archive.sh`.
- Produces: an executable `backup.sh` that runs Phase 0 (report + optional interactive
  commit/push), builds the manifest, assembles the include list, and writes the plaintext archive.

- [ ] **Step 1: Write `backup.sh`**

```bash
#!/usr/bin/env bash
# Back up the lupontes dev environment into one plaintext archive.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"
source "$HERE/lib/manifest.sh"
source "$HERE/lib/git_safety.sh"
source "$HERE/lib/archive.sh"

require_cmd tar zstd jq git
GIT_ROOT="${GIT_ROOT:-$HOME/git}"
OUT="${1:-$HOME/dev-env-backup-$(date +%Y%m%d).tar.zst}"
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT

log "Phase 0: git safety"
git_safety_report "$GIT_ROOT"
if confirm "run interactive commit/push now?"; then
  git_safety_interactive "$GIT_ROOT"
fi

log "Building manifest"
manifest_build > "$STAGE/manifest.json"
cp "$STAGE/manifest.json" "$HOME/.dev-env-manifest.json"  # travels inside .claude-mem-adjacent

log "Assembling include list"
LIST="$STAGE/list.txt"; : > "$LIST"
for p in git .claude .claude.json .claude-mem .mimocode .gitconfig .ssh \
         .m2/settings.xml dotfiles .dev-env-manifest.json; do
  [ -e "$HOME/$p" ] && echo "$p" >> "$LIST"
done

# Exclude installed program trees — programs are reinstalled from official sources,
# never carried over. Patterns are relative to $HOME (tar runs with -C $HOME).
log "Assembling exclude list"
EXCL="$STAGE/exclude.txt"
cat > "$EXCL" <<'EOF'
.claude/plugins/cache
.claude/plugins/marketplaces
.claude/plugins/plugin-catalog-cache.json
.mimocode/node_modules
.mimocode/package-lock.json
EOF
export ARCHIVE_EXCLUDE_FILE="$EXCL"

log "Writing archive"
archive_pack "$LIST" "$OUT"

log "Verifying archive integrity"
archive_list "$OUT" | grep -q '^\.claude/' || die "archive missing .claude"
archive_list "$OUT" | grep -q '^git/'      || die "archive missing git projects"
log "Backup complete: $OUT"
```

- [ ] **Step 2: Lint + smoke test**

Run:
```bash
chmod +x backup.sh
shellcheck backup.sh
# smoke: an isolated temp HOME with a couple of files; answer "n" to the interactive prompt
TMPH=$(mktemp -d)
HOME="$TMPH" GIT_ROOT="$TMPH/git" \
  bash -c 'mkdir -p "$HOME/.claude" "$HOME/git/p"; echo x > "$HOME/.claude/s"; echo y > "$HOME/git/p/f"; printf "n\n" | '"$PWD"'/backup.sh "$HOME/out.tar.zst"'
```
Expected: prints "Backup complete"; `out.tar.zst` exists.

- [ ] **Step 3: Commit**

```bash
git add backup.sh
git commit -m "feat(migration): add backup orchestrator"
```

---

### Task 11: `lib/verify.sh` + `restore.sh` orchestrator

**Files:**
- Create: `lib/verify.sh`
- Create: `tests/verify.bats`
- Create: `restore.sh`

**Interfaces:**
- Consumes: all prior modules + `packages.sh` installers + `repos.sh`.
- Produces:
  - `verify_report GIT_DST` — prints tool versions, `claude --version`, mimo presence, and
    per-project git status under `GIT_DST`; returns 0 only if all critical checks pass. Critical
    checks are collected via `verify_add NAME 0|1`; `verify_report` fails if any critical check is 1.
  - `restore.sh` — idempotent end-to-end restore.

- [ ] **Step 1: Write the failing test for `verify.sh`**

`tests/verify.bats`:
```bash
load test_helper
setup()    { setup_sandbox
             source "$REPO_ROOT_DIR/lib/common.sh"
             source "$REPO_ROOT_DIR/lib/verify.sh"; }
teardown() { teardown_sandbox; }

@test "report fails when a critical check failed" {
  verify_reset
  verify_add "claude" 1
  run verify_report "$HOME/repo"
  [ "$status" -ne 0 ]
}
@test "report passes when all critical checks are ok" {
  verify_reset
  verify_add "claude" 0
  verify_add "mimo" 0
  run verify_report "$HOME/repo"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/verify.bats`
Expected: FAIL — module missing.

- [ ] **Step 3: Write `lib/verify.sh`**

```bash
#!/usr/bin/env bash
# Final verification report. Needs common.sh.

verify_reset() { _VERIFY_FAILS=0; }
verify_add() {   # NAME  0(ok)/1(fail)
  local name="$1" rc="$2"
  if [ "$rc" -eq 0 ]; then printf '  [ok]   %s\n' "$name" >&2
  else printf '  [FAIL] %s\n' "$name" >&2; _VERIFY_FAILS=$((_VERIFY_FAILS+1)); fi
}
verify_report() {
  local dst="$1" d
  log "Final verification"
  for d in "$dst"/*/; do
    [ -d "$d/.git" ] || continue
    printf '  repo %-22s %s\n' "$(basename "$d")" \
      "$(git -C "$d" status -s | wc -l | tr -d ' ') changes" >&2
  done
  if [ "${_VERIFY_FAILS:-0}" -gt 0 ]; then
    warn "$_VERIFY_FAILS critical check(s) failed"; return 1
  fi
  log "all critical checks passed"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats tests/verify.bats && shellcheck lib/verify.sh`
Expected: PASS.

- [ ] **Step 5: Write `restore.sh`**

```bash
#!/usr/bin/env bash
# Restore the dev environment onto a fresh Ubuntu Desktop. Idempotent.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
for m in common manifest archive remap claude_mem plugins mimo verify; do
  # shellcheck source=/dev/null
  source "$HERE/lib/$m.sh"
done
# shellcheck source=/dev/null
source "$HERE/packages.sh"   # provides ensure_* installers (guarded, no side effects)

ARCHIVE="${1:?usage: restore.sh <archive.tar.zst>}"
GIT_SRC="$HOME/git"; GIT_DST="${REPO_ROOT:-$HOME/repo}"

log "1/9 apt prerequisites"; sudo apt-get update -y
sudo apt-get install -y build-essential git curl ca-certificates zstd jq

log "2/9 runtimes (from official sources)"
ensure_node; ensure_bun; ensure_java; ensure_dotnet; ensure_claude_cli
export PATH="$HOME/.local/bin:$PATH"   # claude CLI lands here

log "3/9 extract archive"; archive_unpack "$ARCHIVE" "$HOME"

log "4/9 projects -> $GIT_DST"
[ -d "$HOME/git" ] && [ ! -d "$GIT_DST" ] && mv "$HOME/git" "$GIT_DST"

log "5/9 remap paths git -> repo"
remap_json_paths "$HOME/.claude.json" "$GIT_SRC" "$GIT_DST"
remap_claude_mem "$GIT_SRC" "$GIT_DST"

log "6/9 reinstall claude code plugins (from official marketplaces)"
plugins_reinstall "$HOME/.claude/plugins"
command -v claude >/dev/null 2>&1 && "$HOME/.local/bin/claude" plugin list >/dev/null 2>&1 \
  && verify_add "plugins" 0 || verify_add "plugins" 1

log "7/9 claude-mem CA + connectivity"
MAN="$HOME/.dev-env-manifest.json"
URL=$(manifest_get "$MAN" '.claude_mem.url')
PID=$(manifest_get "$MAN" '.claude_mem.project_id')
CERT="$HOME/.claude/caddy-root.crt"
KEY=$(jq -r '.env.CLAUDE_MEM_SERVER_BETA_API_KEY // ""' "$HOME/.claude/settings.json")
claude_mem_install_ca "$CERT"
verify_reset
if claude_mem_test "$URL" "$CERT" "$KEY"; then verify_add "claude-mem@443" 0
else verify_add "claude-mem@443" 1; fi

log "8/9 mimo code (from npm)"
MIMO_STAGE="$HOME/.mimocode" mimo_reinstall "0.1.4"
mimo_verify && verify_add "mimo" 0 || verify_add "mimo" 1

log "9/9 identity + perms"
chmod 700 "$HOME/.ssh" 2>/dev/null || true
find "$HOME/.ssh" -type f -name 'id_*' ! -name '*.pub' -exec chmod 600 {} \; 2>/dev/null || true
command -v claude >/dev/null 2>&1 && verify_add "claude" 0 || verify_add "claude" 1

verify_report "$GIT_DST"
log "Restore finished. project_id=$PID  url=$URL"
```

- [ ] **Step 6: Lint**

Run: `chmod +x restore.sh && shellcheck restore.sh lib/verify.sh`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add lib/verify.sh tests/verify.bats restore.sh
git commit -m "feat(migration): add verification report and restore orchestrator"
```

---

### Task 12: Full test run + README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Run the whole suite**

Run: `bats tests/ && shellcheck lib/*.sh backup.sh restore.sh repos.sh packages.sh`
Expected: all tests PASS; shellcheck clean.

- [ ] **Step 2: Document usage in `README.md`**

Add a "Migration" section:
```markdown
## Migration to a new machine

1. On the OLD machine: `./backup.sh` — reviews git state (commit/push with your
   approval), then writes `~/dev-env-backup-YYYYMMDD.tar.zst` (plaintext — treat as secret).
2. Copy the archive to the NEW Ubuntu Desktop.
3. On the NEW machine: clone this repo, then `./restore.sh <archive>` — installs
   prerequisites/runtimes, restores projects to `~/repo`, remaps paths, reconnects
   claude-mem on port 443 (tested), and reinstalls Mimo Code. Review the final report.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(migration): document backup and restore usage"
```

---

## Self-Review

**Spec coverage:**
- Git safety (Phase 0, repo-by-repo, no push without approval) → Task 3 + Task 10.
- Encrypted single archive incl. secrets → Task 4 + Task 10.
- Projects `~/git`→`~/repo` → Task 5 (repos.sh) + Task 6 (remap) + Task 11 (restore mv).
- Claude Code prerequisites + CLI (official) + plugins reinstalled from official marketplaces → Task 9 (CLI) + Task 9b (`plugins_reinstall`) + Task 11 (step 6).
- Programs from official sources only; installed trees excluded from backup → Task 4 (`ARCHIVE_EXCLUDE_FILE`) + Task 10 (exclude list) + Task 9/9b/8 (fresh installs).
- claude-mem remote 443, reuse key/project_id, CA, tested, corpus remap → Task 6 + Task 7 + Task 11.
- Mimo Code reinstall functional (fresh npm install, node_modules excluded from backup) → Task 8 + Task 10 (exclude) + Task 11 (step 8).
- Memory continuity (include `~/.claude-mem`) → Task 10 include list.
- `brain` archive-only (non-git) → Task 10 include list (whole `git/` tree) + Task 3 skips non-git.
- Manifest / project-id evaluation → Task 2 + Task 11 report.
- Version-agnostic Ubuntu → Task 9 (`nvm --lts`, apt current) + no hard-coded release.
- Final verification report → Task 11.

**Placeholder scan:** no TBD/TODO; every code step has complete code; test steps have real assertions.

**Type consistency:** function names are consistent across tasks (`manifest_get`, `git_needs_action`, `git_scan_root`, `archive_pack`/`unpack`/`list`, `remap_json_paths`, `remap_claude_mem`, `claude_mem_test`, `mimo_reinstall`/`mimo_verify`, `verify_add`/`verify_report`/`verify_reset`). Injection env vars are consistent (`CLAUDE_MEM_CURL`, `MIMO_NPM`, `MIMO_STAGE`).

**Known real-world caveats (not gaps):**
- `restore.sh` Task 11 Step 5 relies on `packages.sh` being safe to `source` (functions only). If `packages.sh` runs installs at load, guard its body with `[ "${BASH_SOURCE[0]}" = "$0" ]` before sourcing — fold this guard into Task 9.
- The claude-mem live test can only pass from a network where port 443 to the server is reachable; on a blocked network it reports FAIL by design (honest), and the rest of the restore still completes.
