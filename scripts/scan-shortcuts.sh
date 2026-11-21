#!/usr/bin/env bash
# Scan the fetched project sources (not Mathlib) for proof shortcuts.
set -euo pipefail

src="${1:-lean/src}"
out="${2:-shortcut-scan.txt}"
if [[ ! -d "$src" ]]; then
  echo "No source dir $src" >&2
  exit 1
fi

# Whole-word-ish patterns; still report the line so a human can judge comments.
rg -n --glob '*.lean' \
  -e '\bsorry\b' \
  -e '\badmit\b' \
  -e '^\s*axiom\b' \
  -e '\bnative_decide\b' \
  -e '\bunsafe\b' \
  -e '\bunchecked_cast\b' \
  "$src" > "$out" || true

python3 - <<PY
from collections import Counter
from pathlib import Path
text = Path("$out").read_text(errors="replace")
lines = [ln for ln in text.splitlines() if ln.strip()]
keys = ("sorry", "admit", "axiom", "native_decide", "unsafe", "unchecked_cast")
counts = Counter()
for ln in lines:
    low = ln.lower()
    for k in keys:
        if k in low:
            counts[k] += 1
            break
summary = "Shortcut scan of $src: %d matching lines (%s)\n" % (
    len(lines),
    ", ".join(f"{k}={counts[k]}" for k in keys),
)
print(summary)
Path("$out.summary").write_text(summary)
if lines:
    print("First 50 hits:")
    print("\n".join(lines[:50]))
else:
    print("No matches for sorry, admit, axiom, native_decide, unsafe, unchecked_cast.")
PY
