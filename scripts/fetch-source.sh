#!/usr/bin/env bash
# Download the alpo.ge Lean tarball in the 14 published parts, concatenate,
# verify sha256, and extract. Does not commit or upload the sources.
set -euo pipefail

SHA256="${TARBALL_SHA256:-9631b4f020199e580ba86178cb56c6e9b09f690c2369a80dc4334aa93f49c7fc}"
BASE="${TARBALL_BASE:-https://alpo.ge/lean.tar.gz}"
PARTS="${TARBALL_PARTS:-14}"
DEST="${1:-.}"
mkdir -p "$DEST"
cd "$DEST"

echo "Fetching $PARTS parts from $BASE.partNN"
for i in $(seq 1 "$PARTS"); do
  part=$(printf "%s.part%02d" "$BASE" "$i")
  out=$(printf "lean.tar.gz.part%02d" "$i")
  echo "  $part"
  curl -fL --retry 5 --retry-delay 5 --retry-all-errors -o "$out" "$part"
done

echo "Concatenating parts"
cat lean.tar.gz.part* > lean.tar.gz
rm -f lean.tar.gz.part*

actual=$(sha256sum lean.tar.gz | awk '{print $1}')
echo "sha256 expected: $SHA256"
echo "sha256 actual:   $actual"
if [[ "$actual" != "$SHA256" ]]; then
  echo "::error::SHA-256 mismatch. Refusing to build."
  exit 1
fi

echo "Extracting"
tar -xzf lean.tar.gz
rm -f lean.tar.gz
test -f lean/lakefile.toml
test -f lean/lean-toolchain
echo "Extracted toolchain: $(cat lean/lean-toolchain)"
