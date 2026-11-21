# Independent build check of a claimed Lean 4 proof of the Riemann Hypothesis

This repository runs a **public GitHub Actions** workflow that fetches the Lean 4 formalization announced at [alpo.ge](https://alpo.ge/remark.pdf), builds it, and prints the axioms of the two main theorems. It is an independent build-and-axiom check of an **unverified claimed proof**. A green workflow does not, by itself, establish the Riemann Hypothesis.

The Lean sources are **not stored in this repository**. Each run downloads them from the author's site, checks a sha256 digest, and builds them.

## Upstream source

- Announcement: <https://alpo.ge/remark.pdf>
- Tarball, published as 14 parts: <https://alpo.ge/lean.tar.gz.part01> … <https://alpo.ge/lean.tar.gz.part14>
- The single URL `https://alpo.ge/lean.tar.gz` serves the author's homepage, not the archive.
- Concatenated archive size: 239,275,554 bytes
- sha256: `9631b4f020199e580ba86178cb56c6e9b09f690c2369a80dc4334aa93f49c7fc`
- Toolchain: `leanprover/lean4:v4.33.1`
- Mathlib revision: `0df444a360eaa60ab8c11dca51a86af692955474`
- Lake package name: `tree`

The workflow builds the `Main` target, which contains:

```lean
theorem riemannHypothesis : RiemannHypothesis := rhOfAll
theorem LFunction_eq_zero_re : DirichletLZerosOnLine := claimAll.2.1
```

and then runs `lake env lean src/AxiomCheck.lean`, which is:

```lean
import Main
#print axioms riemannHypothesis
#print axioms LFunction_eq_zero_re
```

`AxiomCheck.lean` is the only Lean file that belongs to this repository. It is copied into the fetched tree at build time.

## Licence of the formalization

No licence was found that allows redistributing the author's Lean files:

- The tarball has no `LICENSE`, `COPYING`, `README`, `NOTICE`, or SPDX headers in the author's sources.
- [remark.pdf](https://alpo.ge/remark.pdf) and its text mention only the part URLs. They contain no licence or copyright grant.
- Paths such as `https://alpo.ge/LICENSE` return the author's personal homepage, not a licence.

Without a licence, this repo uses **approach A**: the workflow downloads the tarball and checks its sha256. The Lean sources are not committed here, and they are not uploaded to Kaggle. The optional Kaggle dataset stores only compiled `.olean` files and Lake hash files, as a build cache.

The MIT licence in this repository covers only the workflow, scripts, and documentation here.

## How the workflow is chained

A single GitHub-hosted job may run for at most 6 hours. A full build is expected to take longer, so jobs are chained:

1. Each `Verify RH Lean` job frees runner disk, installs [elan](https://github.com/leanprover/elan), fetches and verifies the tarball, runs `lake exe cache get` for Mathlib, restores any previous olean cache, then runs `timeout --signal=INT 5h lake build Main`.
2. Compiled project oleans are packed with zstd and uploaded as a new version of a **public Kaggle dataset** (`<KAGGLE_USERNAME>/rh-lean-olean-cache`). Old dataset versions are deleted so the 200 GB dataset cap is not filled with stale checkpoints. Files are named `*.bin` so Kaggle does not auto-unpack the archive.
3. If the 5-hour cap was hit and the cache was saved, a sibling workflow named `Chain Kick` succeeds. That success retriggers `Verify RH Lean` (`workflow_run`). This avoids a personal access token: `GITHUB_TOKEN` cannot start a new workflow run directly.
4. When `lake build Main` finishes, the job prints axioms, scans the fetched sources for `sorry`, `axiom`, `native_decide`, `unsafe` (and `admit` / `unchecked_cast`), and writes a job summary. The kick workflow then fails on purpose, which stops the chain.

### Secrets you need to add

The chain can only resume if the olean cache is stored between jobs. Add these repository secrets (`Settings → Secrets and variables → Actions`):

- `KAGGLE_USERNAME`
- `KAGGLE_KEY`

The Kaggle account should be able to create a public dataset (Kaggle may require phone verification). The API token comes from the Kaggle account settings. Until those secrets exist, you can still run a **smoke test**, but a full 5-hour slot cannot persist its cache and will not chain.

GitHub Actions cache (10 GB per repo) and release assets are not the primary store: a partial build of `Main` already produced several gigabytes of oleans, and the final cache may exceed 10 GB. Kaggle's per-dataset limit is 200 GB.

## Running it

1. Add the two Kaggle secrets above.
2. Open the **Actions** tab, choose **Verify RH Lean**, and click **Run workflow**.
3. Leave **smoke** unchecked for a real chained build. Check it for a short end-to-end test (fetch, Mathlib cache, ~12 minutes of `lake build`).
4. Watch the job summary for olean counts, shortcut-scan results, and (when the build finishes) `#print axioms`.

## Kaggle notebooks versus GitHub runners

Helen suggested a public Kaggle dataset for the cache. That is a good fit. **Running the build itself inside Kaggle notebooks is not a better primary plan** than GitHub-hosted runners:

| | GitHub `ubuntu-latest` (public repo) | Kaggle CPU notebook |
|---|---|---|
| Session length | 6 hours (then we chain) | 12 hours |
| CPU / RAM | 4 vCPU / 16 GB | 4 CPU / 30 GB |
| Saved disk | Documented guarantee is only 14 GB; public runners often have a much larger disk (~145 GB, tens of GB free after cleanup), but that extra space is not guaranteed | 20 GB auto-saved in `/kaggle/working` |
| Artifact store | 10 GB Actions cache; awkward as the primary store | Datasets up to 200 GB (this is what we use) |
| Quota | Standard runners are free and unlimited on public repos, subject to fair use | CPU sessions have no published weekly cap; GPU is ~30 hours/week and is not useful for Lean |

The longer notebook session and extra RAM would help, but the 20 GB `/kaggle/working` save limit is far too small for this olean tree (a partial `Main` build already exceeded that in `.setup.json` plus oleans). Scratch space on notebooks is not a documented size. GitHub Actions, with Kaggle used only as the 200 GB cache, is the better default. The disk risk to watch is still the runner: Lean also writes large regenerable `setup.json` files, which the workflow deletes during the build so the oleans themselves can fit.

A later option, if runner disk turns out to be insufficient, is a larger machine rather than a Kaggle notebook.

## Status

The statement of the two theorems matches Mathlib's `RiemannHypothesis` and the corresponding Dirichlet L-function claim, and a source scan for the usual proof shortcuts was clean in a desktop checkout. The formalization is large and looks machine-generated. This repository does **not** claim that the proof is correct, or that a full build has completed.

Expected wall-clock time for a chained `lake build Main` on a 4-vCPU runner is still uncertain. A full build of every default Lake target was previously estimated at roughly 70–90 hours on that hardware. `Main` appears to depend on a much smaller slice of the tree than all 175,187 Lean files, so the chained `Main` build may finish in substantially less time. Plan for several 5-hour jobs (on the order of one to several days) until the first full run reports otherwise.
