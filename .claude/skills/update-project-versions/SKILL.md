---
name: update-project-versions
description: Advance the pinned ref of tested projects in versions.txt to a newer upstream release (bump stale pins). Use when asked to update the projects, bump versions, refresh pins, or apply the staleness audit's findings.
---

# Update tested-project versions

Bump the pinned refs in `versions.txt` toward newer upstream releases. The tested projects
are upstream open-source projects the suite validates SCALE against — bumping a pin changes
which version of that project gets cloned and built on the next `test.sh` run.

## Scope of this skill

- **Edits only `versions.txt`** — the single source of truth for refs. Never hardcode a ref
  in a clone script; never touch the README status table (CI-generated).
- **Does not build or run tests.** That's `test.sh`. After bumping, the user (or CI) runs the
  suite to see whether the new version still passes — failures are expected for projects SCALE
  doesn't fully support yet.
- Default target is every project that is *behind*; accept a project name or list to bump only those.

## First, know the latest releases

Run the `upstream-staleness` skill (or its method) to get each project's latest upstream
release and pin classification. Reuse its version-scheme gotchas verbatim — build-number tags
(llama.cpp/ggml), RAPIDS calendar versions, gromacs year-series, nv-codec-headers `nX.Y.Z`,
Gitea-hosted cycles, etc.

## Bump policy — what to advance, what to leave

| Pin type | Action |
|---|---|
| **Version tag** (`vX.Y.Z`, build number, year-series) | Bump to the latest **stable** release tag, matching the existing scheme exactly (keep the `v`/`n`/`b` prefix style). |
| **Prerelease pin** (e.g. FLAMEGPU2 `v2.0.0-rc.2`) | Bump to the latest prerelease; switch to stable only once one ships. |
| **Commit hash** | **Leave by default and flag.** Commits are often pinned deliberately (compat, avoiding an upstream regression). Only bump when explicitly asked or `--include-commits`; then prefer a release commit, else default-branch HEAD. |
| **Branch** (`main`/`master`/`gpu_new`/`spectral`) | Leave — it floats with upstream. Just report. |
| **Frozen / intentional** | **Do NOT bump without confirming intent:** `pytorch-1.8.1` (legacy-API validation), `caffe`/`thrust`/`nerf-cuda` (dead upstream), `House-Prices`/`datasets` (static data repos), `openmpi` (pinned to the 4.1 series). |

When unsure whether a pin is intentional, ask before changing it rather than silently bumping.

## Method

1. Read `versions.txt`; for each target project resolve the upstream URL from its `*clone*.sh`
   (sub-deps like `GOMC_Examples`/`ucx`/`datasets` have no own dir — grep all `*.sh`).
2. `git ls-remote --tags --refs <url>` to find the latest appropriate ref (no rate limit).
3. **Verify the chosen ref exists before writing it:** `git ls-remote --tags <url> '<newref>'`
   must return a hit. Never write an unverified ref — a truncated tag list once falsely
   reported `warp v1.14.0` / `cuSZ v0.16.2` as missing when both existed.
4. Edit only the ref token in `versions.txt`, preserving the `<name> <ref>` format and line order.
5. Report a `versions.txt` diff plus a per-project summary (`old → new`, and which pins were
   left untouched and why). Do not commit unless asked.

## Execution

~66 independent upstream lookups — fan out with parallel subagents (batches of ~9–10) using a
**reasoning-capable model** (the work is version-scheme judgement, not mechanical), per the
`subagent-model-selection` guidance. Verify any surprising result yourself before writing it.

## Caveats

- A successful bump does not imply the test still passes — updating a pin can change which
  features are exercised and surface new gaps.
- Check a project's git history / nearby script comments before overriding a commit pin; it may
  encode a known-good revision.
