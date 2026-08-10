load test_helper
setup()    { setup_sandbox; }
teardown() { teardown_sandbox; }

@test "repos.sh references REPO_ROOT and defaults to repos" {
  run grep -E 'REPO_ROOT' "$REPO_ROOT_DIR/repos.sh"
  [ "$status" -eq 0 ]
  run grep -E 'REPO_ROOT:-\$\{?HOME\}?/repos|HOME/repos' "$REPO_ROOT_DIR/repos.sh"
  [ "$status" -eq 0 ]
}
@test "repos.sh no longer hard-codes ~/git as the destination root" {
  run grep -E '(^|[^A-Za-z_])\$HOME/git($|[^A-Za-z_])' "$REPO_ROOT_DIR/repos.sh"
  [ "$status" -ne 0 ]
}
