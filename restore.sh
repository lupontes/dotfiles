#!/usr/bin/env bash
# Restore projects + Claude Code plugins onto a fresh Ubuntu Desktop.
# Assumes Claude Code itself was already installed manually (per the migration docs).
# Idempotent. Does NOT reinstall runtimes, claude-mem, or Mimo Code — see README
# "Migration" section for those manual follow-ups (code for them already exists
# in docs/superpowers/plans/2026-07-15-dev-env-migration.md if you want to automate later).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
for m in common manifest archive remap plugins verify; do
  # shellcheck source=/dev/null
  source "$HERE/lib/$m.sh"
done

require_cmd tar zstd jq
command -v claude >/dev/null 2>&1 || die "claude CLI not found — install Claude Code manually first"

ARCHIVE="${1:?usage: restore.sh <archive.tar.zst>}"
GIT_SRC="$HOME/git"
GIT_DST="${REPO_ROOT:-$HOME/repos}"

log "1/4 extract archive"
archive_unpack "$ARCHIVE" "$HOME"

log "2/4 projects -> $GIT_DST"
if [ -d "$GIT_SRC" ] && [ ! -d "$GIT_DST" ]; then
  mv "$GIT_SRC" "$GIT_DST"
elif [ -d "$GIT_SRC" ] && [ -d "$GIT_DST" ]; then
  warn "$GIT_DST already exists — leaving $GIT_SRC in place, merge manually"
fi

log "3/4 remap paths git -> repos"
remap_json_paths "$HOME/.claude.json" "$GIT_SRC" "$GIT_DST"
remap_claude_mem "$GIT_SRC" "$GIT_DST"

log "4/4 reinstall claude code plugins (from official marketplaces)"
verify_reset
if plugins_reinstall "$HOME/.claude/plugins"; then
  verify_add "plugins" 0
else
  verify_add "plugins" 1
fi
verify_add "claude" 0

verify_report "$GIT_DST"
MAN="$HOME/.dev-env-manifest.json"
if [ -f "$MAN" ]; then
  log "Restore finished. See $MAN for the source manifest (versions, claude-mem project_id)."
else
  log "Restore finished."
fi
