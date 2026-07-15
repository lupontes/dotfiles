load test_helper
setup() { setup_sandbox
          source "$REPO_ROOT_DIR/lib/common.sh"
          source "$REPO_ROOT_DIR/lib/archive.sh"
          # generate a throwaway age keypair for the crypto seam
          age-keygen -o "$HOME/id.age" 2>"$HOME/pub.txt"
          export CLAUDE_BACKUP_AGE_IDENTITY="$HOME/id.age"
          export CLAUDE_BACKUP_AGE_RECIPIENT="$(grep -o 'age1[0-9a-z]*' "$HOME/pub.txt")"
          mkdir -p "$HOME/.claude" "$HOME/git/proj"
          echo settings > "$HOME/.claude/s.json"
          echo code     > "$HOME/git/proj/main.c"
          printf '.claude\ngit\n' > "$HOME/list.txt"; }
teardown() { teardown_sandbox; }

@test "pack then list shows archived paths" {
  archive_pack "$HOME/list.txt" "$HOME/out.age"
  [ -f "$HOME/out.age" ]
  run archive_list "$HOME/out.age"
  [[ "$output" == *".claude/s.json"* ]]
  [[ "$output" == *"git/proj/main.c"* ]]
}
@test "unpack restores file contents into a new home" {
  archive_pack "$HOME/list.txt" "$HOME/out.age"
  mkdir -p "$HOME/dest"
  archive_unpack "$HOME/out.age" "$HOME/dest"
  [ "$(cat "$HOME/dest/git/proj/main.c")" = "code" ]
}

@test "pack fails when a listed source path is missing" {
  printf '.claude\nno-such-path\n' > "$HOME/list.txt"
  run archive_pack "$HOME/list.txt" "$HOME/out.age"
  [ "$status" -ne 0 ]
}

@test "unpack fails on wrong identity" {
  archive_pack "$HOME/list.txt" "$HOME/out.age"
  age-keygen -o "$HOME/wrong.age" 2>"$HOME/wrong-pub.txt"
  export CLAUDE_BACKUP_AGE_IDENTITY="$HOME/wrong.age"
  run archive_unpack "$HOME/out.age" "$HOME/dest"
  [ "$status" -ne 0 ]
}
