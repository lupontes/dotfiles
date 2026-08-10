#!/usr/bin/env bash
# Back up the lupontes dev environment into one plaintext archive.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"
# shellcheck source=lib/manifest.sh
source "$HERE/lib/manifest.sh"
# shellcheck source=lib/git_safety.sh
source "$HERE/lib/git_safety.sh"
# shellcheck source=lib/archive.sh
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
cp "$STAGE/manifest.json" "$HOME/.dev-env-manifest.json"

log "Assembling include list"
LIST="$STAGE/list.txt"; : > "$LIST"
for p in git .claude .claude.json .claude-mem .mimocode .gitconfig .ssh \
         .m2/settings.xml .dev-env-manifest.json; do
  [ -e "$HOME/$p" ] && echo "$p" >> "$LIST"
done

# Exclude installed program trees — programs are reinstalled from official sources,
# never carried over. Keep the small plugin manifests (installed_plugins.json,
# known_marketplaces.json, data/) so plugins can be reinstalled on the destination.
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
warn "Archive is PLAINTEXT and contains SSH keys + API keys/tokens in cleartext."
warn "Treat $OUT as a secret: hand-carry it, then securely wipe it after restore."
log "Backup complete: $OUT"
