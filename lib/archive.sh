#!/usr/bin/env bash
# Encrypted archive pack/unpack. Needs common.sh. Requires tar, zstd, age.

_age_encrypt() {  # stdin -> stdout
  if [ -n "${CLAUDE_BACKUP_AGE_RECIPIENT:-}" ]; then
    age -r "$CLAUDE_BACKUP_AGE_RECIPIENT"
  else
    age -p
  fi
}
_age_decrypt() {  # stdin -> stdout
  if [ -n "${CLAUDE_BACKUP_AGE_IDENTITY:-}" ]; then
    age -d -i "$CLAUDE_BACKUP_AGE_IDENTITY"
  else
    age -d
  fi
}

archive_pack() {
  local list="$1" out="$2"
  require_cmd tar zstd age
  # -C $HOME so archived paths are relative to home; --files-from for the include list.
  tar -C "$HOME" -cf - --files-from="$list" \
    | zstd -q -19 -T0 \
    | _age_encrypt > "$out"
  [ -s "$out" ] || die "archive is empty: $out"
  log "archive written: $out"
}

archive_unpack() {
  local in="$1" dest="$2"
  require_cmd tar zstd age
  mkdir -p "$dest"
  _age_decrypt < "$in" | zstd -d -q | tar -C "$dest" -xf -
  log "archive extracted into: $dest"
}

archive_list() {
  local in="$1"
  require_cmd tar zstd age
  _age_decrypt < "$in" | zstd -d -q | tar -tf -
}
