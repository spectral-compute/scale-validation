#!/usr/bin/env python3
"""Comment out HeCBench benchmarks that use GPU features the target arch can't compile.

HeCBench registers benchmarks as a flat list of names in ``src/CMakeLists.txt``::

    set(HECBENCH_POC_BENCHMARKS
        jacobi
        bfs
        ...
    )

Rather than hardcoding the names of benchmarks known to fail, this script scans each
benchmark's source directory for the API symbols a rule declares unsupported, and
comments out the matching entries in place. New benchmarks that use a blocked feature
are caught automatically on the next version bump.

Entries are commented out (``#name``), not deleted, so the CMakeLists diff stays
readable and each exclusion carries its reason in the build log.

Usage:
    ./disable_unsupported.py --src-dir <HeCBench> --arch gfx942 [--model cuda] [--dry-run]
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

# Source extensions worth scanning. Keeps the grep off data files and vendored blobs.
SOURCE_GLOBS = ("*.cu", "*.cuh", "*.cpp", "*.cc", "*.cxx", "*.c", "*.h", "*.hpp", "*.hxx", "*.inl")


@dataclass
class Rule:
    """A reason to exclude a benchmark, and how to detect it in the source."""

    name: str
    reason: str
    # Symbols that unambiguously mean "this benchmark uses the feature".
    strong: str
    # Symbols that *might* mean it, but collide with ordinary identifiers. Matches here
    # without a strong match are reported for human review, never auto-disabled.
    weak: str = ""
    # Target architectures the rule applies to, as full-match regexes.
    archs: list[str] = field(default_factory=list)

    def applies_to(self, arch: str) -> bool:
        return any(re.fullmatch(pattern, arch) for pattern in self.archs)


# ---------------------------------------------------------------------------
# Rules. Add new ones here; nothing else needs to change.
# ---------------------------------------------------------------------------

TEXTURE_STRONG = "|".join(
    (
        # Texture/surface object API
        r"cudaTextureObject_t",
        r"cudaSurfaceObject_t",
        r"cudaTextureDesc",
        r"cudaResourceDesc",
        r"cudaResourceViewDesc",
        r"cudaCreate(Texture|Surface)Object",
        r"cudaDestroy(Texture|Surface)Object",
        r"cudaGetTextureObjectResourceDesc",
        # Legacy texture/surface reference API (removed in CUDA 12, but still present
        # in older benchmarks). Requires a declarator after the <> to avoid matching
        # C++ template prose or unrelated `surface<...>` types.
        r"texture[[:space:]]*<[^<>]*>[[:space:]]+[A-Za-z_]",
        r"surface[[:space:]]*<[^<>]*>[[:space:]]+[A-Za-z_]",
        r"cudaBindTexture[A-Za-z]*",
        r"cudaUnbindTexture",
        r"cudaBindSurfaceToArray",
        r"cudaGetTextureReference",
        # CUDA arrays and channel descriptors (only ever used to back textures/surfaces)
        r"cudaMallocArray",
        r"cudaMalloc3DArray",
        r"cudaMallocMipmappedArray",
        r"cudaFreeArray",
        r"cudaFreeMipmappedArray",
        r"cudaArray_t",
        r"cudaArray_const_t",
        r"cudaMipmappedArray[A-Za-z_]*",
        r"cudaMemcpy2?(To|From)Array",
        r"cudaMemcpyArrayToArray",
        r"cudaCreateChannelDesc",
        r"cudaChannelFormatDesc",
        r"cudaGetChannelDesc",
        # Fetch intrinsics with no plausible user-defined namesake
        r"tex1Dfetch",
        r"tex[12]DLayered[A-Za-z]*",
        r"tex2Dgather",
        r"tex2Dgrad",
        r"tex2Dlod",
        r"texCubemap[A-Za-z]*",
        r"surf[123]Dread",
        r"surf[123]Dwrite",
        r"surf[12]DLayered(read|write)",
        # Driver API equivalents
        r"CUtexObject",
        r"CUtexref",
        r"cuTexObjectCreate",
        r"cuTexRefSet[A-Za-z]*",
        r"cuArray(3D)?Create",
    )
)

# Bare fetch intrinsics. `tex2D` in particular collides with hand-rolled sampling
# helpers (e.g. debayer defines its own `tex2D()` over plain global memory, and
# opticalFlow's software fallback is `tex2D_sw`). A benchmark genuinely using texture
# hardware always trips a strong symbol too, so these only ever warn.
TEXTURE_WEAK = r"\btex1D\b|\btex2D\b|\btex3D\b"

RULES = [
    Rule(
        name="texture",
        reason="CUDA texture/surface objects; unsupported on this arch",
        strong=TEXTURE_STRONG,
        weak=TEXTURE_WEAK,
        # CDNA3 (MI300 series) has no texture/image hardware.
        archs=[r"gfx94[0-9]"],
    ),
]


# ---------------------------------------------------------------------------
# CMakeLists parsing
# ---------------------------------------------------------------------------

LIST_START = re.compile(r"^\s*set\(HECBENCH_POC_BENCHMARKS\b")
# A benchmark entry: indentation, a bare name, nothing else. Skips comments and `)`.
ENTRY = re.compile(r"^(\s*)([A-Za-z0-9_][A-Za-z0-9_.+-]*)\s*$")


def find_list_span(lines: list[str]) -> tuple[int, int]:
    """Return [start, end) line indices of the benchmark list body."""
    for i, line in enumerate(lines):
        if LIST_START.match(line):
            for j in range(i + 1, len(lines)):
                if lines[j].strip().startswith(")"):
                    return i + 1, j
            raise SystemExit("error: unterminated set(HECBENCH_POC_BENCHMARKS ...) block")
    raise SystemExit("error: could not find set(HECBENCH_POC_BENCHMARKS ...) in CMakeLists.txt")


# ---------------------------------------------------------------------------
# Scanning
# ---------------------------------------------------------------------------


def grep_benchmarks(src: Path, pattern: str, model: str) -> set[str]:
    """Return the set of benchmark names whose <name>-<model>/ tree matches `pattern`."""
    if not pattern:
        return set()
    cmd = ["grep", "-rlE", pattern]
    for glob in SOURCE_GLOBS:
        cmd += ["--include", glob]
    cmd += ["--", "."]
    proc = subprocess.run(cmd, cwd=src, capture_output=True, text=True)
    # grep exits 1 for "no matches", which is not an error here.
    if proc.returncode not in (0, 1):
        raise SystemExit(f"error: grep failed ({proc.returncode}): {proc.stderr.strip()}")

    suffix = f"-{model}"
    names = set()
    for path in proc.stdout.splitlines():
        top = path.lstrip("./").split("/", 1)[0]
        if top.endswith(suffix):
            names.add(top[: -len(suffix)])
    return names


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src-dir", required=True, type=Path, help="HeCBench checkout root")
    ap.add_argument("--arch", required=True, help="target GPU arch, e.g. gfx942 or sm_120")
    ap.add_argument("--model", default="cuda", help="programming model dir suffix (default: cuda)")
    ap.add_argument("--dry-run", action="store_true", help="report without editing CMakeLists.txt")
    args = ap.parse_args()

    src = (args.src_dir / "src").resolve()
    if not src.is_dir():
        raise SystemExit(f"error: {src} is not a directory")

    cmakelists = src / "CMakeLists.txt"
    lines = cmakelists.read_text().splitlines()
    start, end = find_list_span(lines)

    active = {}
    for i in range(start, end):
        m = ENTRY.match(lines[i])
        if m:
            active[m.group(2)] = i

    active_rules = [r for r in RULES if r.applies_to(args.arch)]
    if not active_rules:
        print(f"[disable_unsupported] no rules apply to {args.arch}; nothing to do")
        return 0

    disabled: dict[str, str] = {}
    review: dict[str, str] = {}

    for rule in active_rules:
        strong = grep_benchmarks(src, rule.strong, args.model)
        weak = grep_benchmarks(src, rule.weak, args.model)
        for name in sorted(strong & active.keys()):
            disabled.setdefault(name, rule.reason)
        for name in sorted((weak - strong) & active.keys()):
            review.setdefault(name, rule.name)

    for name, reason in disabled.items():
        i = active[name]
        indent = ENTRY.match(lines[i]).group(1)
        lines[i] = f"{indent}#{name}  # SCALE-DISABLED({args.arch}): {reason}"

    label = "[disable_unsupported]"
    rule_names = ", ".join(r.name for r in active_rules)
    print(f"{label} arch={args.arch} model={args.model} rules={rule_names}")
    print(f"{label} {len(active)} benchmarks active, disabling {len(disabled)}")
    for name, reason in sorted(disabled.items()):
        print(f"{label}   disabled: {name} -- {reason}")
    for name, rule_name in sorted(review.items()):
        print(f"{label}   review:   {name} -- weak '{rule_name}' match only, left enabled")

    if args.dry_run:
        print(f"{label} dry run, {cmakelists} unchanged")
    elif disabled:
        cmakelists.write_text("\n".join(lines) + "\n")
        print(f"{label} updated {cmakelists}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
