#!/usr/bin/env python3
"""Build the job matrix for benchmarking CI.

Like gen_matrix.py, this is for our internal CI, and probably not useful to you if
you don't work at Spectral.

Inputs, from the environment. Lists are whitespace- or comma-separated:

  BENCH_PROJECTS    Projects with a benchmarks/ subdir. Unset or empty = all.
  BENCH_TOOLCHAINS  scale-amd, scale-nvidia, nvcc-nvidia, hip-amd. Unset = all,
                    but set and empty is an error (no toolchains ticked).
  BENCH_ISAS        GPU ISAs, e.g. "gfx1100 sm_89", or a JSON array. A toolchain
                    only pairs with ISAs from its own vendor. Required.
  BENCH_REPEATS     Checked to be a whole number of at least 1, if set.
  BENCH_TOOLCHAIN_FIELDS
                    Optional JSON object of extra fields to add to each job, by
                    toolchain, e.g. {"hip-amd": {"toolkit": "/opt/rocm"}, ...}.
                    If it's set, every selected toolchain needs an entry.

Strictness, each on (1) by default:

  BENCH_ISAS_STRICT      Fail if an ISA isn't used by any selected toolchain,
                         rather than skipping it.
  BENCH_PROJECTS_STRICT  Fail if a project has no benchmark scripts for a
                         selected toolchain, rather than skipping that pair.

CI turns these off when it's using a default list (all ISAs, or every project)
rather than one that was typed in.

Each job has project, toolchain, compiler (benchmark.py's --compiler), isa and
needs_scale, plus its toolchain's BENCH_TOOLCHAIN_FIELDS. Writes matrix=<json> and needs_scale=<bool> to $FORGEJO_OUTPUT, or prints them
if that's unset, and prints a summary of what will run to stderr.

Locally:
  BENCH_ISAS='gfx1100 sm_89' python3 util/gen_benchmark_matrix.py
"""

import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

VALIDATION = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(VALIDATION))
import benchmark  # noqa: E402

ISA_RE = re.compile(r"gfx[0-9a-f]+|sm_[0-9]+[a-z]?")


@dataclass(frozen=True)
class Toolchain:
    compiler: str  # benchmark.py's --compiler
    isa_prefix: str


TOOLCHAINS = {
    "scale-amd": Toolchain("scale", "gfx"),
    "scale-nvidia": Toolchain("scale", "sm_"),
    "nvcc-nvidia": Toolchain("nvcc", "sm_"),
    "hip-amd": Toolchain("hip", "gfx"),
}


def parse_list(var):
    """A JSON array or a space/comma separated list."""
    value = os.environ.get(var, "").strip()
    if value.startswith("["):
        return json.loads(value)
    return [x for x in re.split(r"[\s,]+", value) if x]


def strict(var):
    return os.environ.get(var, "1") == "1"


def select(requested, available, what):
    if not requested:
        return available
    unknown = sorted(set(requested) - set(available))
    if unknown:
        sys.exit(f"Unknown {what}: {', '.join(unknown)}. Available: {', '.join(available)}")
    return list(dict.fromkeys(requested))


def toolchain_fields(toolchains):
    value = os.environ.get("BENCH_TOOLCHAIN_FIELDS", "").strip()
    if not value:
        return {name: {} for name in toolchains}
    try:
        fields = json.loads(value)
    except json.JSONDecodeError as e:
        sys.exit(f"BENCH_TOOLCHAIN_FIELDS isn't valid JSON: {e}")
    missing = [name for name in toolchains if not isinstance(fields.get(name), dict)]
    if missing:
        sys.exit(f"BENCH_TOOLCHAIN_FIELDS has no fields for: {', '.join(missing)}")
    return fields


def check_repeats():
    repeats = os.environ.get("BENCH_REPEATS")
    if repeats is not None and not re.fullmatch(r"[1-9][0-9]*", repeats.strip()):
        sys.exit(f"repeats must be a whole number of at least 1, not '{repeats}'")
    return repeats


def print_summary(matrix, toolchains, repeats):
    rows = {}
    for job in matrix:
        isas, projects = rows.setdefault(job["toolchain"], ({}, {}))
        isas[job["isa"]] = None
        projects[job["project"]] = None

    out = sys.stderr
    jobs = f"{len(matrix)} benchmark job{'s' * (len(matrix) != 1)}"
    print(f"\n{jobs}" + (f", {repeats} repeats each" if repeats else "") + "\n", file=out)
    print(f"{'TOOLCHAIN':<14}{'ISAS':<24}PROJECTS", file=out)
    for name in toolchains:
        if name in rows:
            isas, projects = (", ".join(d) for d in rows[name])
            print(f"{name:<14}{isas:<24}{projects}", file=out)
        else:
            print(f"{name:<14}{'-':<24}(nothing to run)", file=out)


def main():
    repeats = check_repeats()

    if "BENCH_TOOLCHAINS" in os.environ and not parse_list("BENCH_TOOLCHAINS"):
        sys.exit("No toolchains selected")
    toolchains = select(parse_list("BENCH_TOOLCHAINS"), list(TOOLCHAINS), "toolchains")
    projects = select(parse_list("BENCH_PROJECTS"), benchmark.benchmark_projects(), "benchmarks")
    fields = toolchain_fields(toolchains)

    isas = list(dict.fromkeys(parse_list("BENCH_ISAS")))
    if not isas:
        sys.exit("No ISAs given, and no default configured")
    bad = [isa for isa in isas if not ISA_RE.fullmatch(isa)]
    if bad:
        sys.exit(f"Not a GPU ISA: {', '.join(bad)} (expected e.g. gfx1100 or sm_89)")

    def usable(isa, name):
        return isa.startswith(TOOLCHAINS[name].isa_prefix)

    unused = [isa for isa in isas if not any(usable(isa, tc) for tc in toolchains)]
    if unused and strict("BENCH_ISAS_STRICT"):
        sys.exit(
            f"No selected toolchain runs on {', '.join(unused)}. "
            f"Selected: {', '.join(toolchains)}"
        )
    for isa in unused:
        print(f"skip: no selected toolchain runs on {isa}", file=sys.stderr)
    for name in toolchains:
        if not any(usable(isa, name) for isa in isas):
            print(f"skip: no {TOOLCHAINS[name].isa_prefix}* ISA for {name}", file=sys.stderr)

    matrix = []
    missing = []
    for project in projects:
        for name in toolchains:
            tc = TOOLCHAINS[name]
            scripts = benchmark.resolve_scripts(VALIDATION / project, benchmark.Compiler(tc.compiler))
            if not any(s.is_benchmark for s in scripts):
                missing.append(f"{project} ({name})")
                continue
            for isa in isas:
                if usable(isa, name):
                    matrix.append({
                        **fields[name],
                        "project": project,
                        "toolchain": name,
                        "compiler": tc.compiler,
                        "isa": isa,
                        "needs_scale": tc.compiler == "scale",
                    })

    if missing and strict("BENCH_PROJECTS_STRICT"):
        sys.exit(f"No benchmark scripts for: {', '.join(missing)}")
    for m in missing:
        print(f"skip: no benchmark scripts for {m}", file=sys.stderr)
    if not matrix:
        sys.exit("The filters matched nothing")
    print_summary(matrix, toolchains, repeats)

    outputs = {
        "matrix": json.dumps(matrix),
        "needs_scale": json.dumps(any(j["needs_scale"] for j in matrix)),
    }
    out = os.environ.get("FORGEJO_OUTPUT")
    with open(out, "a") if out else sys.stdout as f:
        for k, v in outputs.items():
            f.write(f"{k}={v}\n")


if __name__ == "__main__":
    main()
