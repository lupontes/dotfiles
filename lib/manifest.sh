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
