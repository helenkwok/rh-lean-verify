#!/usr/bin/env bash
# Download or upload the olean cache as a public Kaggle dataset version.
# Requires KAGGLE_USERNAME and KAGGLE_KEY. Does not log the key.
set -euo pipefail

cmd="${1:-}"
WORKDIR="${WORKDIR:-.}"
SLUG="${KAGGLE_DATASET_SLUG:-rh-lean-olean-cache}"
UPLOAD_DIR="${CACHE_DIR:-$WORKDIR/kaggle-upload}"
DOWNLOAD_DIR="${KAGGLE_DOWNLOAD_DIR:-$WORKDIR/kaggle-download}"

need_creds() {
  if [[ -z "${KAGGLE_USERNAME:-}" || -z "${KAGGLE_KEY:-}" ]]; then
    echo "Kaggle credentials are not set (need repo secrets KAGGLE_USERNAME and KAGGLE_KEY)."
    return 1
  fi
  mkdir -p "$HOME/.kaggle"
  umask 077
  printf '{"username":"%s","key":"%s"}\n' "$KAGGLE_USERNAME" "$KAGGLE_KEY" > "$HOME/.kaggle/kaggle.json"
  chmod 600 "$HOME/.kaggle/kaggle.json"
}

dataset_id() {
  echo "${KAGGLE_USERNAME}/${SLUG}"
}

write_metadata() {
  local dir="$1"
  mkdir -p "$dir"
  python3 - <<PY
import json, os, pathlib
username = os.environ["KAGGLE_USERNAME"]
slug = os.environ.get("KAGGLE_DATASET_SLUG", "rh-lean-olean-cache")
meta = {
    "id": f"{username}/{slug}",
    "title": "RH Lean olean build cache (unverified claimed proof)",
    "subtitle": "Compiled Lean 4 oleans for an independent build check. Not the source.",
    "description": """# RH Lean olean build cache

This dataset holds **compiled** Lean 4 artifacts (`.olean` files and Lake hash files) produced while independently building the claimed Riemann Hypothesis formalization published at https://alpo.ge/.

It is a build cache for GitHub Actions, not a source release. The Lean sources are **not** included. The original formalization was published without a licence; this cache is provided only so a chained CI build can resume, and it does not grant rights to the underlying work.

See the companion GitHub repository for the workflow, the expected sha256 of the upstream tarball, and the verification status.
""",
    "isPrivate": False,
    "licenses": [{"name": "other"}],
    "keywords": ["mathematics", "theorem-proving"],
}
pathlib.Path("$dir/dataset-metadata.json").write_text(json.dumps(meta, indent=2) + "\n")
print("Wrote", "$dir/dataset-metadata.json", "id=", meta["id"])
PY
}

dataset_exists() {
  kaggle datasets list --user "$KAGGLE_USERNAME" --csv 2>/dev/null \
    | awk -F, -v id="$(dataset_id)" 'NR>1 {print $1}' \
    | grep -Fxq "$id"
}

download() {
  need_creds || return 2
  mkdir -p "$DOWNLOAD_DIR"
  if ! dataset_exists; then
    echo "Dataset $(dataset_id) does not exist yet; starting from a clean tree."
    return 1
  fi
  echo "Downloading $(dataset_id)"
  kaggle datasets download -d "$(dataset_id)" -p "$DOWNLOAD_DIR" --force
  shopt -s nullglob
  zips=("$DOWNLOAD_DIR"/*.zip)
  if ((${#zips[@]})); then
    unzip -o "${zips[0]}" -d "$DOWNLOAD_DIR"
    rm -f "${zips[0]}"
  fi
  ls -lh "$DOWNLOAD_DIR"
}

upload() {
  need_creds || return 2
  if [[ ! -d "$UPLOAD_DIR" ]]; then
    echo "Nothing to upload at $UPLOAD_DIR"
    return 1
  fi
  write_metadata "$UPLOAD_DIR"
  local msg="${KAGGLE_VERSION_MESSAGE:-olean cache update $(date -u +%Y-%m-%dT%H:%MZ)}"
  if dataset_exists; then
    echo "Creating a new version of $(dataset_id)"
    # Keep only the latest version so the 200 GB dataset cap is not filled
    # with stale checkpoints.
    kaggle datasets version -p "$UPLOAD_DIR" -m "$msg" -r skip --dir-mode skip -d
  else
    echo "Creating public dataset $(dataset_id)"
    kaggle datasets create -p "$UPLOAD_DIR" --public -r skip --dir-mode skip
  fi
}

case "$cmd" in
  download) download ;;
  upload) upload ;;
  exists) need_creds && dataset_exists ;;
  *) echo "usage: $0 download|upload|exists" >&2; exit 2 ;;
esac
