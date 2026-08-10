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

# 0 (needs action) if dirty>0 OR ahead>0 OR missing upstream.
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
  local root="$1"
  local lines=() line name dir state msg
  mapfile -t lines < <(git_scan_root "$root")
  for line in "${lines[@]}"; do
    name=$(cut -f1 <<< "$line"); state=$(cut -f2- <<< "$line")
    dir="$root/$name"
    [ "$state" = "NOT_GIT" ] && continue
    git_needs_action "$state" || continue
    log "== $name =="; git -C "$dir" status -s >&2; git -C "$dir" --no-pager diff --stat >&2
    if confirm "commit changes in $name?"; then
      printf 'Conventional Commit message: ' >&2; read -r msg
      git -C "$dir" add -A
      if git -C "$dir" diff --cached --quiet; then
        warn "nothing staged to commit in $name"
      else
        git -C "$dir" commit -qm "$msg"
      fi
    fi
    if confirm "push $name to its remote?"; then
      if git -C "$dir" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
        git -C "$dir" push || warn "push failed for $name (remote rejected or unreachable) — skipping, resolve manually"
      else
        git -C "$dir" push -u origin "$(git -C "$dir" rev-parse --abbrev-ref HEAD)" \
          || warn "push failed for $name (remote rejected or unreachable) — skipping, resolve manually"
      fi
    fi
  done
}
