#!/usr/bin/env bash
# Shared helpers. Sourcing defines functions only (no side effects).
[ -n "${COMMON_STRICT:-}" ] && set -euo pipefail

log()  { printf '[*] %s\n' "$*" >&2; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

# confirm PROMPT -> reads one line from stdin; 0 for y/Y/yes, else 1.
confirm() {
  local reply
  printf '%s [y/N] ' "$1" >&2
  read -r reply || return 1
  case "$reply" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# require_cmd NAME... -> die on first missing command.
require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "required command not found: $c"
  done
}
