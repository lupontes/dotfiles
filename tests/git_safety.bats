load test_helper
setup()    { setup_sandbox
             source "$REPO_ROOT_DIR/lib/common.sh"
             source "$REPO_ROOT_DIR/lib/git_safety.sh"
             export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t
             export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
             mkdir -p "$HOME/root"; }
teardown() { teardown_sandbox; }

mk_repo() { git init -q "$1"; ( cd "$1" && echo a > a.txt && git add a.txt \
            && git commit -qm init ); }

@test "clean & synced repo (with upstream) needs no action" {
  mk_repo "$HOME/root/clean"
  git init -q --bare "$HOME/remote.git"
  ( cd "$HOME/root/clean" && git remote add origin "$HOME/remote.git" \
    && git push -qu origin "$(git rev-parse --abbrev-ref HEAD)" )
  state=$(git_repo_state "$HOME/root/clean")
  dirty=$(echo "$state" | cut -f2)
  [ "$dirty" -eq 0 ]
  run git_needs_action "$state"
  [ "$status" -ne 0 ]
}
@test "clean repo with no upstream needs action" {
  mk_repo "$HOME/root/no-upstream"
  state=$(git_repo_state "$HOME/root/no-upstream")
  dirty=$(echo "$state" | cut -f2)
  [ "$dirty" -eq 0 ]
  run git_needs_action "$state"
  [ "$status" -eq 0 ]
}
@test "dirty repo is detected and needs action" {
  mk_repo "$HOME/root/dirty"; echo b >> "$HOME/root/dirty/a.txt"
  state=$(git_repo_state "$HOME/root/dirty")
  [ "$(echo "$state" | cut -f2)" -eq 1 ]
  run git_needs_action "$state"
  [ "$status" -eq 0 ]
}
@test "non-git dir is reported NOT_GIT by the scan" {
  mkdir -p "$HOME/root/plain"
  run git_scan_root "$HOME/root"
  [[ "$output" == *"plain	NOT_GIT"* ]]
}
