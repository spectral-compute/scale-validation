---
name: upstream-staleness
description: For every project in the SCALE validation suite, check its upstream repository and report how far behind the latest release the pinned ref is. Use when asked to audit the freshness of tested projects, find stale pins, or "how far behind are we" across the suite.
---

# Upstream staleness audit

Report, for each project under test, how far behind upstream the pinned ref is.

## Source of truth

- `versions.txt` — the pinned ref (tag / commit hash / branch) per project. This is the
  authoritative list of what's tested. Iterate over THIS, not the directory listing.
- Upstream URL — read from each project's `*clone*.sh` (or `00-clone.sh`). Sub-dependencies
  (e.g. `GOMC_Examples`, `ucx`, `datasets`) have no own directory; grep all `*.sh` for their URL.
- Directories NOT in `versions.txt` (e.g. `gpusnek`, `kokkos`, `lightgbm`, `parrot`, `sage`,
  `ScalingElections`, `tensorflow`) are inactive/WIP — exclude them but list them as skipped.

## Method (per project)

1. `git ls-remote --tags --refs <url>` — enumerate release tags. **No rate limit; always do this.**
2. Identify the latest STABLE release (ignore rc/alpha/beta/nightly/dev unless that's all there is;
   flag when the pin or the latest is itself a prerelease).
3. Classify the pinned ref and report the gap:
   - **Version tag** → version delta + roughly how many releases behind (count intervening tags).
   - **Commit hash** → report latest release; quantify the commit gap only if the GitHub compare API
     is reachable (see below), else report the pinned commit's age vs. latest release.
   - **Branch** (main/master/feature) → note it tracks a moving branch; report latest release tag for context.
4. Optional commit-gap quantification via GitHub API (`WebFetch`), used SPARINGLY:
   - `https://api.github.com/repos/OWNER/REPO/compare/PINNED...LATESTTAG` → `ahead_by` = commits the
     latest tag is ahead of the pin.
   - `https://api.github.com/repos/OWNER/REPO/commits/PINNED` → the pinned commit's date.
   - Unauthenticated limit is ~60 req/hr shared across ALL subagents. On HTTP 403, skip gracefully —
     do not retry. Prefer `git ls-remote` for everything possible.

## Version-scheme gotchas (verified)

- **llama.cpp / ggml** use monotonic build-number tags like `b9522`; gap = numeric difference of build numbers.
- **RAPIDS** (cudf/cugraph/cuml) use calendar versions `vYY.MM.NN`, released ~every 2 months.
- **cuda-samples** tags track CUDA versions (`v12.9`, `v13.3`). **gromacs** uses year-series (`v2025.4`).
- **nv-codec-headers** (the `ffmpeg` project) uses `nX.Y.Z`. **openmpi** is pinned to the 4.1 series; 5.0.x is the active line.
- **thrust** standalone repo is archived (moved into NVIDIA/cccl); **caffe**, **nerf-cuda** are unmaintained;
  **pytorch-1.8.1** is intentionally legacy. Report these as frozen-by-design, not "behind".
- Repos with no real tags (placeholder `v0.0.0` or none): timemachine, heraclespp, RabbitCT, hashinator,
  gpu_jpeg2k, llm.c, HeCBench, CUDALibrarySamples, nvflip, House-Prices, datasets — commit-pin is the only option.
- **cycles** is hosted on Gitea (projects.blender.org), NOT GitHub — `ls-remote` only, no GitHub API.
- The three opencv repos (opencv / opencv_contrib / opencv_extra) are pinned in lockstep to one release era.

## Execution

There are ~66 projects, each an independent upstream query — fan out with parallel subagents
(batches of ~9–10) and aggregate their structured reports. These agents do **version-gap reasoning**
(comparing schemes, judging staleness), so use a reasoning-capable model, NOT Haiku. (Haiku is for the
mechanical clone+build agents — see the `subagent-model-selection` memory.)

Always VERIFY surprising findings yourself before reporting (a subagent's truncated tag list once falsely
claimed `warp v1.14.0` and `cuSZ v0.16.2` didn't exist — both do). A quick `git ls-remote --tags <url> '<tag>'`
confirms existence.

## Output

Group projects by severity: far behind → moderate → slightly behind → current → branch/commit-pin (no
baseline) → frozen-by-design. Per project give: pinned ref, latest upstream release (+date if obtained),
and a one-line gap. Flag any pin that doesn't exist upstream or any suspected `versions.txt` typo.
