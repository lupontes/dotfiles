load test_helper
setup()    { setup_sandbox
             source "$REPO_ROOT_DIR/lib/common.sh"
             source "$REPO_ROOT_DIR/lib/verify.sh"; }
teardown() { teardown_sandbox; }

@test "report fails when a critical check failed" {
  verify_reset
  verify_add "claude" 1
  run verify_report "$HOME/repos"
  [ "$status" -ne 0 ]
}
@test "report passes when all critical checks are ok" {
  verify_reset
  verify_add "claude" 0
  verify_add "plugins" 0
  run verify_report "$HOME/repos"
  [ "$status" -eq 0 ]
}
