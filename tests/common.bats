load test_helper
setup()    { setup_sandbox; source "$REPO_ROOT_DIR/lib/common.sh"; }
teardown() { teardown_sandbox; }

@test "confirm returns 0 on y" {
  run bash -c 'source "'"$REPO_ROOT_DIR"'/lib/common.sh"; printf "y\n" | confirm "ok?"'
  [ "$status" -eq 0 ]
}
@test "confirm returns 1 on n" {
  run bash -c 'source "'"$REPO_ROOT_DIR"'/lib/common.sh"; printf "n\n" | confirm "ok?"'
  [ "$status" -eq 1 ]
}
@test "die exits non-zero and prints message" {
  run bash -c 'source "'"$REPO_ROOT_DIR"'/lib/common.sh"; die "boom"'
  [ "$status" -eq 1 ]
  [[ "$output" == *"boom"* ]]
}
@test "require_cmd fails for a missing binary" {
  run bash -c 'source "'"$REPO_ROOT_DIR"'/lib/common.sh"; require_cmd definitely_not_a_real_cmd_xyz'
  [ "$status" -ne 0 ]
}
