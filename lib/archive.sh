#!/usr/bin/env bash
# Plaintext archive pack/unpack. Needs common.sh. Requires tar, zstd.

archive_pack() {
  local list="$1" out="$2"
  require_cmd tar zstd
  # Optional exclude patterns (installed program trees) via ARCHIVE_EXCLUDE_FILE.
  local exargs=()
  [ -n "${ARCHIVE_EXCLUDE_FILE:-}" ] && exargs=(--exclude-from="$ARCHIVE_EXCLUDE_FILE")
  # -C $HOME so archived paths are relative to home; --files-from for the include list.
  tar -C "$HOME" "${exargs[@]}" -cf - --files-from="$list" | zstd -q -19 -T0 > "$out"
  local st=("${PIPESTATUS[@]}")
  [ "${st[0]}" -eq 0 ] || die "tar failed (${st[0]})"
  [ "${st[1]}" -eq 0 ] || die "zstd failed (${st[1]})"
  [ -s "$out" ] || die "archive is empty: $out"
  log "archive written: $out"
}

archive_unpack() {
  local in="$1" dest="$2"
  require_cmd tar zstd
  mkdir -p "$dest"
  zstd -d -q < "$in" | tar -C "$dest" -xf -
  local st=("${PIPESTATUS[@]}")
  [ "${st[0]}" -eq 0 ] || die "zstd decompress failed (${st[0]})"
  [ "${st[1]}" -eq 0 ] || die "tar extract failed (${st[1]})"
  log "archive extracted into: $dest"
}

archive_list() {
  local in="$1"
  require_cmd tar zstd
  zstd -d -q < "$in" | tar -tf -
}
