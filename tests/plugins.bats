load test_helper
setup()    { setup_sandbox
             source "$REPO_ROOT_DIR/lib/common.sh"
             source "$REPO_ROOT_DIR/lib/plugins.sh"
             mkdir -p "$HOME/man"
             cat > "$HOME/man/known_marketplaces.json" <<'JSON'
{ "claude-plugins-official": { "source": { "source": "github", "repo": "anthropics/claude-plugins-official" } },
  "thedotmack": { "source": { "source": "github", "repo": "thedotmack/claude-mem" } },
  "handoff-marketplace": { "source": { "source": "github", "repo": "willseltzer/claude-handoff" } },
  "headroom-marketplace": { "source": { "source": "github", "repo": "headroomlabs-ai/headroom" } } }
JSON
             cat > "$HOME/man/installed_plugins.json" <<'JSON'
{ "version": 2, "plugins": {
  "superpowers@claude-plugins-official": [ { "version": "6.2.0" } ],
  "claude-mem@thedotmack": [ { "version": "13.14.0" } ],
  "handoff@handoff-marketplace": [ { "version": "1.0.0" } ],
  "headroom@headroom-marketplace": [ { "version": "0.22.3" } ] } }
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
  [[ "$output" == *"plugin marketplace add willseltzer/claude-handoff"* ]]
  [[ "$output" == *"plugin marketplace add headroomlabs-ai/headroom"* ]]
}
@test "installs each plugin by name@marketplace" {
  plugins_reinstall "$HOME/man"
  run cat "$HOME/claude.log"
  [[ "$output" == *"plugin install superpowers@claude-plugins-official"* ]]
  [[ "$output" == *"plugin install claude-mem@thedotmack"* ]]
  [[ "$output" == *"plugin install handoff@handoff-marketplace"* ]]
  [[ "$output" == *"plugin install headroom@headroom-marketplace"* ]]
}
@test "missing manifest returns 0 without calling claude" {
  rm -f "$HOME/man/installed_plugins.json"
  run plugins_reinstall "$HOME/man"
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/claude.log" ]
}
