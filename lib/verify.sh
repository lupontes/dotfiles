#!/usr/bin/env bash
# Final verification report. Needs common.sh.

verify_reset() { _VERIFY_FAILS=0; }
verify_add() {   # NAME  0(ok)/1(fail)
  local name="$1" rc="$2"
  if [ "$rc" -eq 0 ]; then printf '  [ok]   %s\n' "$name" >&2
  else printf '  [FAIL] %s\n' "$name" >&2; _VERIFY_FAILS=$((_VERIFY_FAILS+1)); fi
}
verify_report() {
  local dst="$1" d
  log "Final verification"
  for d in "$dst"/*/; do
    [ -d "$d/.git" ] || continue
    printf '  repo %-22s %s\n' "$(basename "$d")" \
      "$(git -C "$d" status -s | wc -l | tr -d ' ') changes" >&2
  done
  if [ "${_VERIFY_FAILS:-0}" -gt 0 ]; then
    warn "$_VERIFY_FAILS critical check(s) failed"; return 1
  fi
  log "all critical checks passed"
}
