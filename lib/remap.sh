#!/usr/bin/env bash
# Remap source project paths to destination paths across configs. Needs common.sh.

# Rewrite every string value containing OLD to use NEW (keys included, at any
# depth, since .claude.json keys nested "projects" entries by absolute path).
# Two full walk passes: keys first (bottom-up over every object), then values.
remap_json_paths() {
  local file="$1" old="$2" new="$3" tmp
  [ -f "$file" ] || { warn "remap_json_paths: no file $file"; return 0; }
  tmp="$(mktemp)"
  jq --arg old "$old" --arg new "$new" '
    walk(if type=="object" then with_entries(.key |= gsub($old; $new)) else . end)
    | walk(if type=="string" then gsub($old; $new) else . end)
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
  printf '{"from":"%s","to":"%s","corpus_remap":{"git":"repos"}}\n' "$old" "$new" \
    > "$dir/.cwd-remap-$tag"
  log "claude-mem cwd remap marker written ($tag)"
}
