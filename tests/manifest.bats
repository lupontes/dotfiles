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
