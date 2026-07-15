# Shared bats helpers: run each test in an isolated fake HOME.
setup_sandbox() {
  export REPO_ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  export OLD_HOME_UNUSED=1
}
teardown_sandbox() { [ -n "${TEST_HOME:-}" ] && rm -rf "$TEST_HOME"; }
