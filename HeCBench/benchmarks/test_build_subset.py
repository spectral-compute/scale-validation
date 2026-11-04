#!/usr/bin/env python3
"""Test build_subset.py with a fake cmake (no compiler needed).

Run: python3 HeCBench/benchmarks/test_build_subset.py
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "build_subset.py"

# Fake cmake: `--target help` lists registered targets; a build creates
# bin/<model>/<name> for each requested target except "broken-cuda", and
# records its argv so the test can check what was asked for.
FAKE_CMAKE = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
log = Path(os.environ["FAKE_LOG"])
with log.open("a") as f:
    f.write(json.dumps(args) + "\n")
if args[0] == "--preset":
    d = Path("build") / args[1]
    d.mkdir(parents=True)
    (d / "CMakeCache.txt").write_text("CMAKE_GENERATOR:INTERNAL=Ninja\n")
    sys.exit(0)
d = Path(args[1])
targets = [args[i + 1] for i, a in enumerate(args) if a == "--target"]
if targets == ["help"]:
    print("The following are some of the valid targets for this Makefile:")
    for t in ["all", "clean", "good-cuda", "graphB+-cuda", "broken-cuda",
              "notinsubset-cuda", "good-cuda.dir"]:
        print(f"{t}: phony")
    sys.exit(0)
rc = 0
for t in targets:
    name, _, model = t.rpartition("-")
    if name == "broken":
        rc = 1
        continue
    (d / "bin" / model).mkdir(parents=True, exist_ok=True)
    (d / "bin" / model / name).write_text("")
sys.exit(rc)
'''


class BuildSubsetTest(unittest.TestCase):
    def run_in(self, subset, cmake_ok=True):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        tree = root / "HeCBench"
        (tree / "src/scripts/benchmarks").mkdir(parents=True)
        (tree / "src/scripts/benchmarks/subset.json").write_text(json.dumps(subset))
        bindir = root / "bin"
        bindir.mkdir()
        (bindir / "cmake").write_text(FAKE_CMAKE)
        (bindir / "cmake").chmod(0o755)
        logf = root / "cmake.log"
        env = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", FAKE_LOG=str(logf))
        res = subprocess.run([sys.executable, str(SCRIPT), "P", "cuda"], cwd=tree,
                             capture_output=True, text=True, env=env)
        calls = [json.loads(x) for x in logf.read_text().splitlines()] if logf.exists() else []
        summary = tree / "build/P/subset-build.json"
        return res, calls, (json.loads(summary.read_text()) if summary.exists() else None)

    def test_builds_only_registered_subset_targets(self):
        subset = {"good": ["r"], "graphB+": ["r"], "broken": ["r"], "disabled": ["r"]}
        res, calls, summary = self.run_in(subset)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(calls[0], ["--preset", "P"])  # configured on first use
        build = calls[-1]
        targets = [build[i + 1] for i, a in enumerate(build) if a == "--target"]
        self.assertEqual(sorted(targets), ["broken-cuda", "good-cuda", "graphB+-cuda"])
        self.assertNotIn("notinsubset-cuda", targets)
        self.assertEqual(build[-3:], ["--", "-k", "0"])  # Ninja keep-going
        self.assertEqual(summary["built"], ["good", "graphB+"])
        self.assertEqual(summary["failed"], ["broken"])
        self.assertEqual(summary["not_registered"], ["disabled"])
        self.assertIn("failed:         1: broken", res.stderr)

    def test_fails_if_nothing_built(self):
        res, _, summary = self.run_in({"broken": ["r"]})
        self.assertNotEqual(res.returncode, 0)
        self.assertEqual(summary["built"], [])

    def test_fails_if_nothing_registered(self):
        res, calls, _ = self.run_in({"disabled": ["r"]})
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("none of the 1 subset.json benchmarks are registered", res.stderr)


if __name__ == "__main__":
    unittest.main()
