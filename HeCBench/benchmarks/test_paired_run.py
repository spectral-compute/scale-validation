#!/usr/bin/env python3
"""End-to-end test of paired_run.py against a fake HeCBench tree (no GPU).

Run: python3 HeCBench/benchmarks/test_paired_run.py
"""
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
DRIVER = HERE / "paired_run.py"
PRESET = "scale-cuda-sm103"

SUBSET = {
    "good": ["(?:Average kernel execution time: )([0-9.+-e]+)(?: \\(us\\))", ["8"]],
    "fpclose": ["(?:Average kernel execution time: )([0-9.+-e]+)(?: \\(us\\))", []],
    "wrong": ["(?:Average kernel execution time: )([0-9.+-e]+)(?: \\(us\\))", []],
    "selffail": ["(?:Average kernel execution time: )([0-9.+-e]+)(?: \\(us\\))", []],
    "crash": ["(?:Average kernel execution time: )([0-9.+-e]+)(?: \\(us\\))", []],
    "hang": ["(?:Average kernel execution time: )([0-9.+-e]+)(?: \\(us\\))", []],
    "nomatch": ["(?:Average kernel execution time: )([0-9.+-e]+)(?: \\(us\\))", []],
    "bandwidth": ["(?:Bandwidth: )([0-9.+-e]+)(?: GB/s)", []],
    "expectedfail": ["(?:Kernel time : )([0-9.+-e]+)", []],
    "diagok": ["(?:Average kernel execution time: )([0-9.+-e]+)(?: \\(us\\))", []],
    "diagbad": ["(?:Average kernel execution time: )([0-9.+-e]+)(?: \\(us\\))", []],
    "argv0": ["(?:Average kernel execution time: )([0-9.+-e]+)(?: \\(us\\))", []],
    "envcheck": ["(?:Average kernel execution time: )([0-9.+-e]+)(?: \\(us\\))", []],
}
# Like HeCBench's assert: expected failures on stdout, assertion spew on stderr.
ASSERTLIKE = ('echo "Kernel time : 0.1"; echo "Device assert failed as expected"; '
              'echo "main.cu:21: Assertion failed." >&2')
# Prints its own path, like cuda-samples' concurrentKernels; trees differ per compiler.
ARGV0 = 'echo "[$0] - Starting..."; echo "Average kernel execution time: 1 (us)"; echo "sum 3"'
ENVCHECK = 'echo "Average kernel execution time: 1 (us)"; echo "only=[$ONLY_TEST] path=[$MY_PATH]"'


# Per compiler: benchmark -> bash body. $1 is the first subset arg.
BODIES = {
    "ref": {
        "good": 'echo "n=$1"; echo "Average kernel execution time: 10.0 (us)"; echo "sum 12345.678"; echo PASS',
        "fpclose": 'echo "Average kernel execution time: 5 (us)"; echo "result 1.0000000"',
        "wrong": 'echo "Average kernel execution time: 5 (us)"; echo "result 42"; echo PASS',
        "selffail": 'echo "Average kernel execution time: 5 (us)"; echo PASS',
        "crash": 'echo "Average kernel execution time: 5 (us)"; echo PASS',
        "hang": 'echo "Average kernel execution time: 5 (us)"; echo PASS',
        "nomatch": 'echo "Average kernel execution time: 5 (us)"; echo PASS',
        "bandwidth": 'echo "Bandwidth: 100 GB/s"; echo PASS',
        "envcheck": ENVCHECK,
        "argv0": ARGV0,
        "expectedfail": ASSERTLIKE,
        "diagok": 'echo "Average kernel execution time: 1 (us)"; echo "Validation: PASS (5 checkpoints, max_abs=243915.5)"; echo "Relative L2 norm: 8.4e-08"; echo "FILTER TOOK 0.24 (s)"; echo "0.2376 s"',
        "diagbad": 'echo "Average kernel execution time: 1 (us)"; echo "max error 1e-07"; echo PASS',
    },
    "test": {
        "good": 'echo "n=$1"; echo "Average kernel execution time: 20.0 (us)"; echo "sum 12345.678"; echo PASS',
        "fpclose": 'echo "Average kernel execution time: 5 (us)"; echo "result 1.0000001"',
        "wrong": 'echo "Average kernel execution time: 4 (us)"; echo "result 43"; echo PASS',
        "selffail": 'echo "Average kernel execution time: 5 (us)"; echo FAIL',
        "crash": 'echo "partial"; kill -SEGV $$',
        "hang": 'sleep 30',
        "nomatch": 'echo "oops"; echo PASS',
        "bandwidth": 'echo "Bandwidth: 50 GB/s"; echo PASS',
        "envcheck": ENVCHECK,
        "argv0": ARGV0,
        "expectedfail": ASSERTLIKE,
        "diagok": 'echo "Average kernel execution time: 1 (us)"; echo "Validation: PASS (5 checkpoints, max_abs=65983.13)"; echo "Relative L2 norm: 8.7e-08"; echo "FILTER TOOK 0.27 (s)"; echo "0.1658 s"',
        "diagbad": 'echo "Average kernel execution time: 1 (us)"; echo "max error 0.5"; echo PASS',
    },
}


def make_tree(root, comp):
    tree = root / comp / "HeCBench"
    (tree / "src/scripts/benchmarks").mkdir(parents=True)
    (tree / "src/scripts/benchmarks/subset.json").write_text(json.dumps(SUBSET))
    bindir = tree / "build" / PRESET / "bin" / "cuda"
    bindir.mkdir(parents=True)
    for b, body in BODIES[comp].items():
        (tree / "src" / f"{b}-cuda").mkdir()
        p = bindir / b
        p.write_text(f"#!/usr/bin/env bash\n{body}\n")
        p.chmod(0o755)
    tk = root / f"{comp}-toolkit" / "bin"
    tk.mkdir(parents=True)
    if comp == "test":
        (tk / "scaleenv").write_text("export SCALE_ENV=1\n")
    else:
        (tk / "nvcc").write_text("#!/bin/sh\necho fake nvcc\n")
        (tk / "nvcc").chmod(0o755)
    return tree, tk.parent


class PairedRunTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        root = Path(cls.tmp.name)
        specs = []
        for comp in ("ref", "test"):
            tree, tk = make_tree(root, comp)
            specs += ["--compiler", f"{comp}={tree}:{tk}"]
        cls.out = root / "out"
        env = dict(os.environ, PATH="/usr/bin:/bin")  # hide nvidia-smi/numactl/gdb
        run = [sys.executable, str(DRIVER), "run", "--out", str(cls.out), *specs,
               "--gpu", "0", "--gpu", "1", "--rounds", "3", "--warmup-rounds", "1",
               "--timeout", "2", "--no-telemetry", "--no-membind",
               "--env", "test:ONLY_TEST=1", "--env-prepend", "ref:MY_PATH=/x"]
        cls.run_res = subprocess.run(run, capture_output=True, text=True, env=env)
        cls.rep_res = subprocess.run(
            [sys.executable, str(DRIVER), "report", str(cls.out), "--min-pairs", "2"],
            capture_output=True, text=True, env=env)
        cls.rows = {}
        import csv
        if (cls.out / "report.csv").exists():
            with open(cls.out / "report.csv") as f:
                cls.rows = {r["benchmark"]: r for r in csv.DictReader(f)}

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_run_completes_despite_failures(self):
        self.assertEqual(self.run_res.returncode, 0, self.run_res.stderr)
        recs = [json.loads(x) for x in (self.out / "results.jsonl").read_text().splitlines()]
        self.assertEqual(len(recs), len(SUBSET) * 4 * 2)  # benches x rounds x compilers

    def test_statuses(self):
        recs = [json.loads(x) for x in (self.out / "results.jsonl").read_text().splitlines()]
        st = {(r["benchmark"], r["compiler"]): r["status"] for r in recs}
        self.assertEqual(st[("good", "ref")], "ok")
        self.assertEqual(st[("crash", "test")], "signal")
        self.assertEqual(st[("hang", "test")], "timeout")
        self.assertEqual(st[("nomatch", "test")], "no-match")
        self.assertEqual(st[("selffail", "test")], "self-fail")
        # Args from subset.json are passed through.
        self.assertIn("n=8", (self.out / "runs/ref/good/r00-gpu0.stdout").read_text()
                      if (self.out / "runs/ref/good/r00-gpu0.stdout").exists()
                      else (self.out / "runs/ref/good/r00-gpu1.stdout").read_text())

    def test_correctness_verdicts(self):
        self.assertEqual(self.rep_res.returncode, 0, self.rep_res.stderr)
        r = self.rows
        self.assertEqual(r["good"]["output_verdict"], "identical")
        self.assertEqual(r["good"]["correct"], "True")
        self.assertEqual(r["fpclose"]["output_verdict"], "within-tol")
        self.assertEqual(r["fpclose"]["correct"], "True")
        self.assertEqual(r["wrong"]["output_verdict"], "differs")
        self.assertEqual(r["wrong"]["correct"], "False")
        self.assertEqual(r["expectedfail"]["correct"], "True")
        self.assertEqual(r["argv0"]["output_verdict"], "identical")
        self.assertEqual(r["diagok"]["correct"], "True")
        self.assertEqual(r["diagbad"]["output_verdict"], "diag-worse")
        self.assertEqual(r["diagbad"]["correct"], "False")
        for b in ("selffail", "crash", "hang", "nomatch"):
            self.assertEqual(r[b]["correct"], "False", b)
            self.assertEqual(r[b]["output_verdict"], "run-failed", b)

    def test_timing_ratio(self):
        self.assertAlmostEqual(float(self.rows["good"]["ratio_median"]), 2.0)
        # Higher-is-better metric: half the bandwidth is also 2x slower.
        self.assertEqual(self.rows["bandwidth"]["higher_is_better"], "True")
        self.assertAlmostEqual(float(self.rows["bandwidth"]["ratio_median"]), 2.0)
        self.assertEqual(int(self.rows["good"]["n_pairs"]), 3)  # warm-up excluded
        # A wrong-but-faster benchmark gets no timing in the headline.
        self.assertIn("wrong", (self.out / "report.md").read_text())

    def test_per_compiler_env(self):
        ref = next((self.out / "runs/ref/envcheck").glob("*.stdout")).read_text()
        test = next((self.out / "runs/test/envcheck").glob("*.stdout")).read_text()
        self.assertIn("only=[]", ref)
        self.assertIn("only=[1]", test)
        self.assertRegex(ref, r"path=\[/x(:|\])")
        self.assertIn("path=[]", test)

    def test_report_works_without_trees(self):
        # The report must not need the HeCBench trees (e.g. results copied home).
        import shutil
        moved = Path(self.tmp.name) / "elsewhere"
        shutil.copytree(self.out, moved)
        env = dict(os.environ, PATH="/usr/bin:/bin")
        for c in ("ref", "test"):
            os.rename(Path(self.tmp.name) / c, Path(self.tmp.name) / f"{c}-gone")
        try:
            res = subprocess.run([sys.executable, str(DRIVER), "report", str(moved), "--min-pairs", "2"],
                                 capture_output=True, text=True, env=env)
        finally:
            for c in ("ref", "test"):
                os.rename(Path(self.tmp.name) / f"{c}-gone", Path(self.tmp.name) / c)
        self.assertEqual(res.returncode, 0, res.stderr)
        import csv
        with open(moved / "report.csv") as f:
            rows = {r["benchmark"]: r for r in csv.DictReader(f)}
        self.assertEqual(rows["bandwidth"]["higher_is_better"], "True")
        self.assertEqual(rows["good"]["output_verdict"], "identical")

    def test_failures_report(self):
        text = (self.out / "failures.md").read_text()
        self.assertIn("## crash [test]: signal x4", text)
        self.assertIn("SIGSEGV", text)
        self.assertIn("## hang [test]", text)

    def test_resume_skips_done(self):
        env = dict(os.environ, PATH="/usr/bin:/bin")
        meta = json.loads((self.out / "meta.json").read_text())
        specs = []
        for n, c in meta["compilers"].items():
            specs += ["--compiler", f"{n}={c['tree']}:{c['toolkit']}"]
        before = len((self.out / "results.jsonl").read_text().splitlines())
        res = subprocess.run([sys.executable, str(DRIVER), "run", "--out", str(self.out), *specs,
                              "--gpu", "0", "--rounds", "3", "--warmup-rounds", "1", "--timeout", "2",
                              "--no-telemetry", "--no-membind", "--resume"],
                             capture_output=True, text=True, env=env)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(len((self.out / "results.jsonl").read_text().splitlines()), before)


if __name__ == "__main__":
    unittest.main()
