load test_helper
setup() { setup_sandbox
          source "$REPO_ROOT_DIR/lib/common.sh"
          source "$REPO_ROOT_DIR/lib/archive.sh"
          mkdir -p "$HOME/.claude" "$HOME/git/proj"
          echo settings > "$HOME/.claude/s.json"
          echo code     > "$HOME/git/proj/main.c"
          printf '.claude\ngit\n' > "$HOME/list.txt"; }
teardown() { teardown_sandbox; }

@test "pack then list shows archived paths" {
  archive_pack "$HOME/list.txt" "$HOME/out.tar.zst"
  [ -f "$HOME/out.tar.zst" ]
  run archive_list "$HOME/out.tar.zst"
  [[ "$output" == *".claude/s.json"* ]]
  [[ "$output" == *"git/proj/main.c"* ]]
}
@test "unpack restores file contents into a new home" {
  archive_pack "$HOME/list.txt" "$HOME/out.tar.zst"
  mkdir -p "$HOME/dest"
  archive_unpack "$HOME/out.tar.zst" "$HOME/dest"
  [ "$(cat "$HOME/dest/git/proj/main.c")" = "code" ]
}
@test "pack fails when a listed source path is missing" {
  printf '.claude\nnope-missing\n' > "$HOME/bad.txt"
  run archive_pack "$HOME/bad.txt" "$HOME/out.tar.zst"
  [ "$status" -ne 0 ]
}
@test "unpack fails on a corrupt archive" {
  echo "not a zst stream" > "$HOME/corrupt.tar.zst"
  mkdir -p "$HOME/dest"
  run archive_unpack "$HOME/corrupt.tar.zst" "$HOME/dest"
  [ "$status" -ne 0 ]
}
