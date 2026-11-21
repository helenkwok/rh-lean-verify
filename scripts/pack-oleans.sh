#!/usr/bin/env bash
# Pack or unpack project oleans (and lake hash files) for the Kaggle cache.
# setup.json / .c / .ilean / .trace are omitted: they are large and regenerable.
set -euo pipefail

cmd="${1:-}"
shift || true
WORKDIR="${WORKDIR:-.}"
CACHE_DIR="${CACHE_DIR:-$WORKDIR/kaggle-upload}"

lib_dir="$WORKDIR/lean/.lake/build/lib"

pack() {
  mkdir -p "$CACHE_DIR"
  rm -f "$CACHE_DIR"/olean-lib.tar.zst* "$CACHE_DIR"/*.bin
  if [[ ! -d "$lib_dir" ]]; then
    echo "No $lib_dir to pack"
    return 1
  fi
  echo "Packing oleans and hash files from $lib_dir"
  # Stream a filtered tar of lib/ so we do not copy the tree first.
  tar -C "$WORKDIR/lean/.lake/build" \
      --exclude='*.ilean' \
      --exclude='*.trace' \
      --exclude='*.setup.json' \
      --exclude='*.c' \
      -cf - lib \
    | zstd -T0 -10 -o "$CACHE_DIR/olean-lib.tar.zst"
  local size
  size=$(stat -c%s "$CACHE_DIR/olean-lib.tar.zst")
  echo "Packed archive: $size bytes"
  # Keep parts under 2 GiB for any fallback upload path; Kaggle itself
  # also limits a dataset to 50 top-level files.
  split -b 1900M -d -a 2 "$CACHE_DIR/olean-lib.tar.zst" "$CACHE_DIR/olean-lib.tar.zst.part"
  rm -f "$CACHE_DIR/olean-lib.tar.zst"
  for f in "$CACHE_DIR"/olean-lib.tar.zst.part*; do
    mv "$f" "${f}.bin"
  done
  ls -lh "$CACHE_DIR"
  python3 - <<PY
import json, os, pathlib
p = pathlib.Path("$CACHE_DIR")
parts = sorted(p.glob("olean-lib.tar.zst.part*.bin"))
meta = {
    "parts": [x.name for x in parts],
    "bytes": sum(x.stat().st_size for x in parts),
    "olean_count": int(os.environ.get("OLEAN_COUNT", "0")),
}
(p / "manifest.json").write_text(json.dumps(meta, indent=2) + "\n")
print(meta)
PY
}

unpack() {
  local src="${1:-$WORKDIR/kaggle-download}"
  mkdir -p "$WORKDIR/lean/.lake/build"
  shopt -s nullglob
  parts=("$src"/olean-lib.tar.zst.part*.bin "$src"/olean-lib.tar.zst.part* "$src"/olean-lib.tar.zst)
  # Prefer split parts if present.
  split_parts=("$src"/olean-lib.tar.zst.part*.bin)
  if ((${#split_parts[@]})) && [[ -f "${split_parts[0]}" ]]; then
    echo "Unpacking ${#split_parts[@]} Kaggle parts into $WORKDIR/lean/.lake/build"
    cat "${split_parts[@]}" | zstd -d -T0 -c | tar -C "$WORKDIR/lean/.lake/build" -xf -
  elif [[ -f "$src/olean-lib.tar.zst" ]]; then
    echo "Unpacking $src/olean-lib.tar.zst"
    zstd -d -T0 -c "$src/olean-lib.tar.zst" | tar -C "$WORKDIR/lean/.lake/build" -xf -
  else
    echo "No olean archive in $src"
    ls -la "$src" || true
    return 1
  fi
  find "$lib_dir" -name '*.olean' 2>/dev/null | wc -l | awk '{print "Restored oleans:", $1}'
}

case "$cmd" in
  pack) pack ;;
  unpack) unpack "${1:-$WORKDIR/kaggle-download}" ;;
  *) echo "usage: $0 pack|unpack [download-dir]" >&2; exit 2 ;;
esac
