#!/usr/bin/env python3
"""Build only the HeCBench benchmarks that `tools/hecbench run` can time.

`tools/hecbench build` with no names builds every registered benchmark (~485
for CUDA), but `run` only times those in src/scripts/benchmarks/subset.json
(~165), so most of the build is wasted, and a compile failure in a benchmark
that is never timed stops the whole build.

This configures the preset if needed, builds `<name>-<model>` for each
subset.json entry that CMake registered (entries commented out by 01-build.sh's
disable list aren't registered), keeps going past failures, and reports what
was built, skipped and failed. It exits non-zero only if nothing was built.

Run from the HeCBench checkout:  build_subset.py PRESET MODEL
"""
import json
import re
import subprocess
import sys
from pathlib import Path

SUBSET = Path("src/scripts/benchmarks/subset.json")


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def registered_targets(build_dir, wanted):
    """Those of `wanted` that exist as targets in the configured build."""
    out = subprocess.run(["cmake", "--build", str(build_dir), "--target", "help"],
                         capture_output=True, text=True, check=True).stdout
    return {w for w in wanted
            if re.search(r"(^|[\s.])" + re.escape(w) + r"(:|\s|$)", out, re.M)}


def binary_built(build_dir, name, model):
    return (build_dir / "bin" / model / name).exists()


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    preset, model = sys.argv[1], sys.argv[2]
    names = sorted(json.loads(SUBSET.read_text()))
    build_dir = Path("build") / preset

    if not build_dir.exists():
        log(f"Configuring with preset '{preset}'...")
        subprocess.run(["cmake", "--preset", preset], check=True)

    want = {f"{n}-{model}": n for n in names}
    have = registered_targets(build_dir, want)
    missing = sorted(want[t] for t in set(want) - have)
    targets = sorted(have)
    if not targets:
        sys.exit(f"none of the {len(names)} subset.json benchmarks are registered "
                 f"for model {model} in {build_dir}")

    cache = (build_dir / "CMakeCache.txt").read_text()
    keep_going = ["--", "-k", "0"] if "CMAKE_GENERATOR:INTERNAL=Ninja" in cache else []
    cmd = ["cmake", "--build", str(build_dir), "--parallel"]
    for t in targets:
        cmd += ["--target", t]
    cmd += keep_going
    log(f"Building {len(targets)} subset.json targets "
        f"(of {len(names)}; {len(missing)} not registered)")
    rc = subprocess.run(cmd).returncode

    built = [want[t] for t in targets if binary_built(build_dir, want[t], model)]
    failed = sorted(want[t] for t in targets if want[t] not in built)
    log("")
    log("=== subset build summary ===")
    log(f"built:          {len(built)}")
    log(f"not registered: {len(missing)} (disabled, no {model} CMake target, or "
        f"configure skipped it, e.g. missing dvc data; see the configure log): "
        f"{' '.join(missing)}")
    log(f"failed:         {len(failed)}: {' '.join(failed)}")
    (build_dir / "subset-build.json").write_text(json.dumps(
        dict(built=built, not_registered=missing, failed=failed, build_rc=rc), indent=1))
    if not built:
        sys.exit("no subset.json benchmark built")
    if rc != 0:
        log(f"cmake --build exited {rc}; continuing with the {len(built)} that built")
    return 0


if __name__ == "__main__":
    sys.exit(main())
