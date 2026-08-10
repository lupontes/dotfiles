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
