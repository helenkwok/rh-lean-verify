#!/usr/bin/env bash
# Write chain-status/status.json and append a GitHub job summary.
set -euo pipefail

mkdir -p chain-status
python3 - <<'PY'
import json, os, pathlib, datetime
status = {
    "continue": os.environ.get("CHAIN_CONTINUE", "false").lower() == "true",
    "reason": os.environ.get("CHAIN_REASON", ""),
    "smoke": os.environ.get("SMOKE", "false").lower() == "true",
    "lake_exit": int(os.environ.get("LAKE_EXIT", "1")),
    "oleans": int(os.environ.get("OLEAN_COUNT", "0")),
    "cache_saved": os.environ.get("CACHE_SAVED", "false").lower() == "true",
    "cache_backend": os.environ.get("CACHE_BACKEND", "none"),
    "axioms": os.environ.get("AXIOM_OUTPUT", "").strip(),
    "utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%MZ"),
}
pathlib.Path("chain-status/status.json").write_text(json.dumps(status, indent=2) + "\n")
summary = pathlib.Path(os.environ.get("GITHUB_STEP_SUMMARY", "job-summary.md"))
lines = [
    "# RH Lean verification run",
    "",
    f"- Time (UTC): {status['utc']}",
    f"- Smoke test: {status['smoke']}",
    f"- `lake build Main` exit: {status['lake_exit']}",
    f"- Project oleans present: {status['oleans']}",
    f"- Cache saved: {status['cache_saved']} ({status['cache_backend']})",
    f"- Will chain another job: {status['continue']}",
    f"- Reason: {status['reason']}",
    "",
    "This is an **independent build of an unverified claimed proof**. A green",
    "job means that step of the workflow ran; it does not by itself establish",
    "the Riemann Hypothesis.",
    "",
]
if status["axioms"]:
    lines += ["## `#print axioms`", "", "```text", status["axioms"], "```", ""]
summary_text = "\n".join(lines) + "\n"
if "GITHUB_STEP_SUMMARY" in os.environ:
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f:
        f.write(summary_text)
else:
    summary.write_text(summary_text)
print(json.dumps(status, indent=2))
PY
