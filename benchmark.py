#!/usr/bin/env python3
"""Run a project's benchmark scripts, analogous to test.sh.

Scripts are collected from <project>/benchmarks/ and <project>/, keyed on their
name with any backend suffix stripped (e.g. "02-benchmark-hip.sh" and
"02-benchmark-cuda.sh" share the key "02-benchmark"). For each key the variant in
benchmarks/ wins over the one in the project base folder, and within a folder the
most specific suffix matching the selected compiler wins. Unsuffixed scripts run
for every compiler. Scripts then run in lexicographical order of their key, as
test.sh does.
"""

import argparse
import datetime
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent
BENCHMARKS_SUBDIR = "benchmarks"
NON_PROJECT_DIRS = {"util"}

# Suffixes each compiler accepts, most specific first. An unsuffixed script
# ranks below all of them and runs for every compiler.
COMPILER_SUFFIXES = {
    "scale": ["scale", "cuda"],
    "nvcc": ["nvcc", "cuda"],
    "hip": ["hip"],
}
ALL_SUFFIXES = sorted({s for v in COMPILER_SUFFIXES.values() for s in v})
SCRIPT_RE = re.compile(rf"^(?P<key>.+?)(?:-(?P<suffix>{'|'.join(ALL_SUFFIXES)}))?\.sh$")

# Mirrors test.sh: avoids warning spam that overflows CI output limits.
SCALE_NVCC_APPEND_FLAGS = " ".join(
    "-Wno-" + w
    for w in [
        "deprecated-literal-operator", "format", "unknown-warning-option",
        "ignored-qualifiers", "cuda-wrong-side", "unused-function",
        "unused-local-typedef", "unused-parameter", "int-conversion",
        "sign-conversion", "shorten-64-to-32", "template-id-cdtor", "switch",
        "vla-cxx-extension", "missing-template-arg-list-after-template-kw",
        "deprecated-declarations", "c++11-narrowing-const-reference",
        "typename-missing", "unknown-pragmas", "inconsistent-missing-override",
        "unused-private-field", "sign-compare", "pessimizing-move",
        "unused-result", "invalid-constexpr", "unused-but-set-variable",
        "unused-variable", "unused-value", "implicit-const-int-float-conversion",
        "pass-failed",
    ]
)


@dataclass
class Script:
    key: str
    path: Path

    @property
    def is_benchmark(self):
        return "benchmark" in self.path.name

    @property
    def is_test(self):
        return "test" in self.path.name


def benchmark_projects():
    return sorted(
        p.name
        for p in REPO_ROOT.iterdir()
        if p.is_dir() and not p.name.startswith(".") and p.name not in NON_PROJECT_DIRS
        and (p / BENCHMARKS_SUBDIR).is_dir()
    )


def detect_compiler(toolkit):
    # Order matters: a SCALE install also ships bin/nvcc.
    if (toolkit / "bin" / "scaleenv").exists():
        return "scale"
    if (toolkit / "bin" / "nvcc").exists():
        return "nvcc"
    if (toolkit / "bin" / "hipcc").exists() or (toolkit / "bin" / "hipconfig").exists():
        return "hip"
    return None


def pick_variants(directory, compiler):
    """Map key -> best script in `directory` for `compiler`."""
    accepted = COMPILER_SUFFIXES[compiler]
    best = {}  # key -> (rank, path); lower rank is better
    if not directory.is_dir():
        return {}
    for path in directory.glob("*.sh"):
        m = SCRIPT_RE.match(path.name)
        if not m:
            continue
        suffix = m["suffix"]
        if suffix is None:
            rank = len(accepted)
        elif suffix in accepted:
            rank = accepted.index(suffix)
        else:
            continue  # Suffixed for a different compiler.
        key = m["key"]
        if key not in best or rank < best[key][0]:
            best[key] = (rank, path)
    return {k: p for k, (_, p) in best.items()}


def resolve_scripts(project_dir, compiler):
    scripts = pick_variants(project_dir, compiler)
    scripts.update(pick_variants(project_dir / BENCHMARKS_SUBDIR, compiler))
    return [Script(k, scripts[k]) for k in sorted(scripts)]


def source_env(script, *args):
    """Source a bash script and return the resulting environment."""
    out = subprocess.run(
        ["bash", "-c", 'source "$@" >/dev/null && env -0', "_", str(script), *args],
        check=True, stdout=subprocess.PIPE,
    ).stdout
    return dict(e.split("=", 1) for e in out.decode().split("\0") if "=" in e)


def prepend(env, var, value):
    env[var] = f"{value}:{env[var]}" if env.get(var) else value


def build_env(compiler, toolkit, arch, args):
    env = dict(os.environ)

    if compiler == "scale":
        env = source_env(toolkit / "bin" / "scaleenv", arch)
        env.update(
            NVCC_PREPEND_FLAGS="-fdiagnostics-color=always",
            CXXFLAGS="-fdiagnostics-color=always",
            CFLAGS="-fdiagnostics-color=always",
            CMAKE_COLOR_DIAGNOSTICS="ON",
            NVCC_APPEND_FLAGS=SCALE_NVCC_APPEND_FLAGS,
        )
    elif compiler == "nvcc":
        # What scaleenv would otherwise set; see test.sh.
        nvcc = str(toolkit / "bin" / "nvcc")
        for var in ("CUDA_DIR", "CUDA_HOME", "CUDA_PATH", "CUDA_ROOT"):
            env[var] = str(toolkit)
        env.update(
            CUDA_CXX=nvcc, CUDACXX=nvcc, CUCC=nvcc,
            CUDA_INC_DIR=str(toolkit / "include"),
            CUDA_BIN_PATH=str(toolkit / "bin"),
            CUDAARCHS=arch.replace("sm_", ""),
        )
        prepend(env, "PATH", str(toolkit / "bin"))
        prepend(env, "LD_LIBRARY_PATH", str(toolkit / "lib64"))
        prepend(env, "LIBRARY_PATH", str(toolkit / "lib64"))
        prepend(env, "CPATH", str(toolkit / "include"))
    elif compiler == "hip":
        for var in ("ROCM_PATH", "ROCM_HOME", "HIP_PATH"):
            env[var] = str(toolkit)
        env["HIPARCHS"] = arch
        clang = toolkit / "llvm" / "bin" / "clang++"
        if clang.exists():
            env["HIPCXX"] = str(clang)
        prepend(env, "PATH", str(toolkit / "bin"))
        prepend(env, "LD_LIBRARY_PATH", str(toolkit / "lib"))
        prepend(env, "CMAKE_PREFIX_PATH", str(toolkit))

    if args.devices:
        devices = ",".join(args.devices)
        if compiler == "hip":
            env["HIP_VISIBLE_DEVICES"] = devices
        else:
            env["CUDA_VISIBLE_DEVICES"] = devices

    env.update(
        MAKEFLAGS="-O -k",
        TEST_GPU_ARCH=arch,
        BENCHMARK_COMPILER=compiler,
        BENCHMARK_REPEATS=str(args.repeats),
        RESULTS_DIR=str(args.results_dir),
    )
    return env


def create_parser():
    projects = benchmark_projects()
    parser = argparse.ArgumentParser(
        "benchmark",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("workdir", type=Path, help="Directory to clone/build/run in.")
    parser.add_argument(
        "toolkit", type=Path,
        help="Path to a SCALE, NVIDIA CUDA, or ROCm/HIP installation.",
    )
    parser.add_argument("arch", help='GPU architecture to build for, e.g. "gfx1100" or "sm_89".')
    parser.add_argument(
        "project",
        help=f"Project to benchmark (one with a {BENCHMARKS_SUBDIR}/ subdir): {', '.join(projects)}",
    )
    parser.add_argument(
        "-c", "--compiler", choices=sorted(COMPILER_SUFFIXES),
        help="Toolchain type. Auto-detected from the toolkit layout if omitted.",
    )
    parser.add_argument(
        "-d", "--device", dest="devices", action="append", default=[],
        help="GPU index to expose (sets CUDA_/HIP_VISIBLE_DEVICES). Repeatable, "
        "or comma-separated.",
    )
    parser.add_argument(
        "-n", "--repeats", type=int, default=1,
        help="Number of times to run each benchmark script (setup runs once).",
    )
    parser.add_argument(
        "--results-dir", type=Path,
        help="Exported as RESULTS_DIR for scripts to write into (default: WORKDIR/results).",
    )
    parser.add_argument("--keep", action="store_true", help="Don't wipe WORKDIR/PROJECT first.")
    parser.add_argument(
        "--include-tests", action="store_true",
        help="Also run *test* scripts (skipped by default).",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Print the scripts that would run and exit."
    )
    return parser


def main():
    parser = create_parser()
    args = parser.parse_args()

    project_dir = REPO_ROOT / args.project
    if args.project in NON_PROJECT_DIRS or not project_dir.is_dir():
        parser.error(f"unknown project: {args.project}")
    if not (project_dir / BENCHMARKS_SUBDIR).is_dir():
        parser.error(f"{args.project} has no {BENCHMARKS_SUBDIR}/ subdir")
    if args.repeats < 1:
        parser.error("--repeats must be at least 1")
    args.devices = [d for spec in args.devices for d in spec.split(",") if d]

    toolkit = args.toolkit.resolve()
    compiler = args.compiler or detect_compiler(toolkit)
    if compiler is None:
        parser.error(f"{toolkit} is not a SCALE, NVIDIA CUDA or HIP installation (pass --compiler)")

    scripts = [
        s for s in resolve_scripts(project_dir, compiler)
        if (args.include_tests or s.is_benchmark or not s.is_test)
    ]
    if not scripts:
        sys.exit(f"No scripts to run for {args.project} with compiler {compiler}")

    print(f"project:  {args.project}\ncompiler: {compiler} ({toolkit})\narch:     {args.arch}")
    if args.devices:
        print(f"devices:  {','.join(args.devices)}")
    for s in scripts:
        runs = f" x{args.repeats}" if s.is_benchmark else ""
        print(f"  {s.path.relative_to(REPO_ROOT)}{runs}")
    if args.dry_run:
        return

    workdir = args.workdir.resolve()
    run_dir = workdir / args.project
    if not args.keep:
        shutil.rmtree(run_dir, ignore_errors=True)
    run_dir.mkdir(parents=True, exist_ok=True)
    args.results_dir = (args.results_dir or workdir / "results").resolve()
    args.results_dir.mkdir(parents=True, exist_ok=True)

    env = build_env(compiler, toolkit, args.arch, args)

    log_dir = workdir / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M%SZ")
    log_path = log_dir / f"{args.project}-benchmark-{stamp}.log"

    rows = []
    with open(log_path, "w") as log:
        def emit(line):
            sys.stdout.write(line)
            sys.stdout.flush()
            log.write(line)

        emit(f"project: {args.project}\ncompiler: {compiler}\ntoolkit: {toolkit}\n"
             f"arch: {args.arch}\ndevices: {','.join(args.devices) or 'all'}\n"
             f"repeats: {args.repeats}\nstarted: {stamp}\n\n")

        failed = None
        for s in scripts:
            for i in range(1, (args.repeats if s.is_benchmark else 1) + 1):
                label = s.path.name + (f" [{i}/{args.repeats}]" if s.is_benchmark else "")
                emit(f"--------------- Executing {s.path} {label} ---------------\n")
                env["BENCHMARK_REPEAT"] = str(i)
                start = time.monotonic()
                # Run via bash so scripts needn't be executable.
                proc = subprocess.Popen(
                    ["bash", str(s.path)], cwd=run_dir, env=env,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                )
                for raw in proc.stdout:
                    emit(raw.decode(errors="replace"))
                rc = proc.wait()
                rows.append((label, rc, time.monotonic() - start))
                if rc != 0:
                    failed = (label, rc)
                    break
            if failed:
                break

        emit("\n=== RESULTS ===\n")
        emit(f"{'SCRIPT':<42}  {'STATUS':<6}  DETAIL\n")
        for label, rc, dur in rows:
            emit(f"{label:<42}  {'PASS' if rc == 0 else 'FAIL':<6}  exit={rc} duration={dur:.2f}s\n")
        if failed:
            emit(f"FAILED: {failed[0]} (exit {failed[1]}) -- log: {log_path}\n")
            sys.exit(failed[1])
        emit(f"ALL SCRIPTS PASSED -- log: {log_path}\n")


if __name__ == "__main__":
    main()
