load test_helper
setup()    { setup_sandbox
             source "$REPO_ROOT_DIR/lib/common.sh"
             source "$REPO_ROOT_DIR/lib/remap.sh"; }
teardown() { teardown_sandbox; }

@test "remap_json_paths rewrites home/git to home/repos in string values" {
  printf '{"projects":{"%s/git/api":{"x":1}}}' "$HOME" > "$HOME/.claude.json"
  remap_json_paths "$HOME/.claude.json" "$HOME/git" "$HOME/repos"
  run jq -e --arg p "$HOME/repos/api" '.projects | has($p)' "$HOME/.claude.json"
  [ "$status" -eq 0 ]
}
@test "remap_claude_mem writes the cwd-remap marker" {
  mkdir -p "$HOME/.claude-mem"; echo '{}' > "$HOME/.claude-mem/settings.json"
  remap_claude_mem "$HOME/git" "$HOME/repos"
  run bash -c 'ls "$HOME/.claude-mem/".cwd-remap-*-to-* 2>/dev/null'
  [ "$status" -eq 0 ]
}
