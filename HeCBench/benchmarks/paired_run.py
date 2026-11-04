#!/usr/bin/env python3
"""Paired, correctness-checked HeCBench runs comparing two CUDA compilers.

`tools/hecbench run` keeps only the regex-extracted timing and discards stdout,
so a benchmark that prints FAIL (and exits 0, as HeCBench's do) is timed like a
correct one. This driver runs already-built HeCBench binaries directly and,
for every invocation, keeps stdout, stderr, exit status, timestamps, regex
matches and self-check verdicts, so `report` can check correctness first and
only then compare timings.

Design:
- A task is (round, benchmark). It runs both compilers' binaries back to back on
  the same GPU, alternating which goes first between rounds, so each timing
  pair shares a device and a time window and device-to-device variation
  cancels out of the ratio.
- One worker per --gpu GPU:NUMA slot pulls tasks from a shared queue, so
  single-GPU benchmarks run in parallel across GPUs. Each run is pinned to its
  GPU's NUMA node (numactl --cpunodebind/--membind when available).
- Rounds < --warmup-rounds are recorded and correctness-checked but excluded
  from timing.
- Failures (non-zero exit, signal, timeout, no regex match, self-reported
  FAIL) are recorded and never stop the run. With --backtrace, crashes are
  re-run under gdb and hangs are attached to before being killed.
- results.jsonl is appended and flushed after every run; --resume skips tasks
  that already have both compilers recorded.

Subcommands:
  preflight  check GPU/NUMA/tenancy conditions before a run
  run        execute the paired runs
  report     correctness gate + timing comparison from a results dir

Stdlib only; Python >= 3.8.
"""

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import queue
import random
import re
import shlex
import shutil
import signal
import socket
import statistics as st
import subprocess
import sys
import threading
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SUBSET_REL = Path("src/scripts/benchmarks/subset.json")
TIMING_WORDS = re.compile(
    r"(time|elapsed|duration|throughput|bandwidth|speed|perf|"
    r"\b(ms|us|usec|msec|sec|secs|seconds|ns)\b|/s\b|gb/s|gflop|gops|per second|"
    r"\btook\b|\(s\)|\d\s*s\s*$|"
    r"\bdevice\b.*:|gpu name|compute capability)",
    re.I,
)
NUM = re.compile(r"[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?|[-+]?(?:nan|inf)\b", re.I)
PASS_RE = re.compile(r"\bPASS(?:ED)?\b", re.I)
FAIL_RE = re.compile(r"\bFAIL(?:ED|URE|S)?\b", re.I)
PATH_RE = re.compile(r"(?<![\w.])/(?:[^\s/\]\[()'\"]+/)+[^\s/\]\[()'\"]*")
EXPECTED_RE = re.compile(r"as expected", re.I)  # e.g. assert: "failed as expected"
# Lines whose numbers measure distance from a reference rather than being results.
DIAG_WORDS = re.compile(
    r"\b(pass(ed)?|fail(ed|ure)?|errors?|err|diff(erence)?|max_?abs|max_?rel|abs_?err|"
    r"rel_?err|rmse|rsme|rms|mse|norm|reference|tolerance|tol|mismatch(es)?|"
    r"eps(ilon)?|residual|accuracy)\b", re.I)


def fail_lines(text):
    return sum(1 for line in text.splitlines()
               if FAIL_RE.search(line) and not EXPECTED_RE.search(line))
HIGHER_BETTER_RE = re.compile(r"GB/?s|GBytes/sec|per second|/sec|GFLOP|GOPS|throughput", re.I)


# ----------------------------------------------------------------------------
# Small helpers
# ----------------------------------------------------------------------------
def now_iso():
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds")


def sh(cmd, timeout=60, **kw):
    """Run a command for its text output; never raises."""
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, **kw)
        return p.returncode, p.stdout + p.stderr
    except FileNotFoundError:
        return 127, f"{cmd[0]}: not found"
    except subprocess.TimeoutExpired:
        return 124, f"{cmd[0]}: timed out"


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def node_cpus(node):
    text = Path(f"/sys/devices/system/node/node{node}/cpulist").read_text().strip()
    cpus = set()
    for part in text.split(","):
        lo, _, hi = part.partition("-")
        cpus.update(range(int(lo), int(hi or lo) + 1))
    return cpus


def source_env(script, *args):
    out = subprocess.run(
        ["bash", "-c", 'source "$@" >/dev/null && env -0', "_", str(script), *args],
        check=True, stdout=subprocess.PIPE,
    ).stdout
    return dict(e.split("=", 1) for e in out.decode().split("\0") if "=" in e)


def prepend(env, var, value):
    env[var] = f"{value}:{env[var]}" if env.get(var) else value


def parse_env(spec):
    """'[COMPILER:]KEY=VALUE' -> (compiler or None, KEY, VALUE)."""
    k, _, v = spec.partition("=")
    target, _, key = k.rpartition(":")
    if not key:
        sys.exit(f"bad env spec {spec!r}; want [COMPILER:]KEY=VALUE")
    return (target or None), key, v


def runtime_env(toolkit, arch):
    """Environment needed to *run* binaries built by `toolkit`."""
    toolkit = Path(toolkit)
    env = dict(os.environ)
    env.pop("SCALE_ENV", None)
    if (toolkit / "bin" / "scaleenv").exists():
        env = source_env(toolkit / "bin" / "scaleenv", arch)
    elif (toolkit / "bin" / "nvcc").exists():
        prepend(env, "PATH", str(toolkit / "bin"))
        prepend(env, "LD_LIBRARY_PATH", str(toolkit / "lib64"))
    else:
        sys.exit(f"{toolkit}: neither a SCALE (bin/scaleenv) nor NVIDIA CUDA (bin/nvcc) toolkit")
    return env


def gpu_table():
    """index -> dict(bus_id, uuid, name, numa) from nvidia-smi + sysfs."""
    rc, out = sh(["nvidia-smi", "--query-gpu=index,pci.bus_id,uuid,name,persistence_mode,"
                  "compute_mode,clocks.sm,clocks.max.sm,clocks.mem",
                  "--format=csv,noheader,nounits"])
    gpus = {}
    if rc != 0:
        return gpus
    for line in out.strip().splitlines():
        f = [x.strip() for x in line.split(",")]
        if len(f) < 9:
            continue
        bus = f[1].lower()
        # nvidia-smi prints a 8-hex-digit domain; sysfs uses 4.
        sys_bus = bus[4:] if len(bus.split(":")[0]) == 8 else bus
        numa = None
        try:
            numa = int(Path(f"/sys/bus/pci/devices/{sys_bus}/numa_node").read_text())
        except (OSError, ValueError):
            pass
        gpus[int(f[0])] = dict(bus_id=f[1], uuid=f[2], name=f[3], persistence=f[4],
                               compute_mode=f[5], clk_sm=f[6], clk_sm_max=f[7],
                               clk_mem=f[8], numa=numa)
    return gpus


def compute_apps():
    """List of (gpu_uuid, pid, name) currently holding GPU contexts."""
    rc, out = sh(["nvidia-smi", "--query-compute-apps=gpu_uuid,pid,process_name",
                  "--format=csv,noheader"], timeout=30)
    if rc != 0:
        return None
    apps = []
    for line in out.strip().splitlines():
        f = [x.strip() for x in line.split(",")]
        if len(f) >= 3 and f[0].startswith("GPU-"):
            apps.append((f[0], f[1], f[2]))
    return apps


# ----------------------------------------------------------------------------
# Benchmark discovery (mirrors tools/hecbench:run_benchmark)
# ----------------------------------------------------------------------------
def load_subset(tree):
    return load_subset_file(Path(tree) / SUBSET_REL)


def load_subset_file(path):
    data = json.loads(Path(path).read_text())
    out = {}
    for name, v in data.items():
        if isinstance(v, list) and v:
            out[name] = dict(regex=v[0], args=v[1] if len(v) > 1 else [],
                             binary=v[2] if len(v) > 2 else "main")
    return out


def find_binary(tree, preset, name, binary):
    src = Path(tree) / "src" / f"{name}-cuda"
    if (src / binary).exists():
        return src / binary, src
    b = Path(tree) / "build" / preset / "bin" / "cuda" / name
    return (b if b.exists() else None), src


# ----------------------------------------------------------------------------
# Execution
# ----------------------------------------------------------------------------
class Runner:
    def __init__(self, args):
        self.a = args
        self.out = Path(args.out).resolve()
        self.out.mkdir(parents=True, exist_ok=True)
        self.lock = threading.Lock()
        self.stop = threading.Event()
        self.compilers = {}  # name -> dict(tree, env, subset)
        for spec in args.compiler:
            name, _, rest = spec.partition("=")
            tree, _, rest = rest.partition(":")
            toolkit, _, preset = rest.partition(":")
            if not (name and tree and toolkit):
                sys.exit(f"--compiler wants NAME=TREE:TOOLKIT[:PRESET], got {spec!r}")
            env = runtime_env(toolkit, args.arch)
            for kv, mode in [(x, "set") for x in args.env] + [(x, "prepend") for x in args.env_prepend]:
                target, k, v = parse_env(kv)
                if target not in (None, name):
                    continue
                if mode == "set":
                    env[k] = v
                else:
                    prepend(env, k, v)
            env.setdefault("CUDA_DEVICE_ORDER", "PCI_BUS_ID")
            self.compilers[name] = dict(tree=Path(tree).resolve(), toolkit=toolkit, env=env,
                                        preset=preset or args.preset, subset=load_subset(tree))
        if len(self.compilers) != 2:
            sys.exit("need exactly two --compiler entries")
        names = list(self.compilers)
        s0, s1 = (self.compilers[n]["subset"] for n in names)
        if s0 != s1:
            diff = sorted(k for k in set(s0) | set(s1) if s0.get(k) != s1.get(k))
            sys.exit(f"subset.json differs between trees for: {diff[:20]}")
        self.subset = s0
        self.slots = []
        for g in args.gpu:
            idx, _, node = g.partition(":")
            self.slots.append((int(idx), int(node) if node else None))
        self.numactl = shutil.which("numactl") if not args.no_membind else None
        self.gdb = shutil.which("gdb") if args.backtrace else None
        self.gpus = gpu_table()

    # -- metadata -----------------------------------------------------------
    def write_meta(self, benches):
        meta_dir = self.out / "meta"
        meta_dir.mkdir(exist_ok=True)
        # So `report` works away from the machine the trees live on.
        first = next(iter(self.compilers.values()))
        shutil.copyfile(first["tree"] / SUBSET_REL, meta_dir / "subset.json")
        for fname, cmd in {
            "nvidia-smi-q.txt": ["nvidia-smi", "-q"],
            "nvidia-smi-topo.txt": ["nvidia-smi", "topo", "-m"],
            "numactl-H.txt": ["numactl", "-H"],
            "lscpu.txt": ["lscpu"],
            "uname.txt": ["uname", "-a"],
        }.items():
            (meta_dir / fname).write_text(sh(cmd)[1])
        meta = dict(argv=sys.argv, started=now_iso(), host=socket.gethostname(),
                    arch=self.a.arch, preset=self.a.preset, slots=self.slots,
                    gpus=self.gpus, numactl=self.numactl, gdb=self.gdb,
                    timeout=self.a.timeout, rounds=self.a.rounds,
                    warmup_rounds=self.a.warmup_rounds, compilers={})
        meta["scale_validation_rev"] = sh(["git", "-C", str(REPO_ROOT), "rev-parse", "HEAD"])[1].strip()
        meta["scale_validation_dirty"] = sh(["git", "-C", str(REPO_ROOT), "status", "--porcelain"])[1].strip()
        for name, c in self.compilers.items():
            info = dict(tree=str(c["tree"]), toolkit=c["toolkit"], preset=c["preset"],
                        hecbench_rev=sh(["git", "-C", str(c["tree"]), "rev-parse", "HEAD"])[1].strip(),
                        env={k: v for k, v in c["env"].items()
                             if re.match(r"(CUDA|SCALE|LD_|PATH$|OMP|NV)", k)},
                        binaries={})
            # Symlinks like /usr/local/cuda hide which toolkit was really used.
            info["toolkit_realpath"] = os.path.realpath(c["toolkit"])
            info["cuda_path_realpath"] = (os.path.realpath(c["env"]["CUDA_PATH"])
                                          if c["env"].get("CUDA_PATH") else None)
            nvcc = Path(c["toolkit"]) / "bin" / "nvcc"
            info["nvcc_version"] = sh([str(nvcc), "--version"])[1]
            for b in benches:
                path, _ = find_binary(c["tree"], c["preset"], b, self.subset[b]["binary"])
                info["binaries"][b] = dict(path=str(path), sha256=sha256(path)) if path else None
            meta["compilers"][name] = info
        (self.out / "meta.json").write_text(json.dumps(meta, indent=1, default=str))

    # -- telemetry ----------------------------------------------------------
    def start_telemetry(self):
        procs = []
        if not shutil.which("nvidia-smi") or self.a.no_telemetry:
            return procs
        tdir = self.out / "telemetry"
        tdir.mkdir(exist_ok=True)
        ids = ",".join(str(i) for i, _ in self.slots)
        cmds = {
            "gpu.csv": ["nvidia-smi", "-i", ids, "--query-gpu=timestamp,index,clocks.sm,clocks.mem,"
                        "power.draw,temperature.gpu,utilization.gpu,memory.used,"
                        "clocks_event_reasons.active", "--format=csv",
                        "-lms", str(self.a.telemetry_ms)],
            "apps.csv": ["nvidia-smi", "--query-compute-apps=timestamp,gpu_uuid,pid,process_name,"
                         "used_memory", "--format=csv", "-l", "1"],
        }
        for fname, cmd in cmds.items():
            f = open(tdir / fname, "a")
            procs.append((subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT), f))
        return procs

    # -- one invocation -----------------------------------------------------
    def build_cmd(self, binary, run_args, node):
        cmd = [str(binary)] + [str(x) for x in run_args]
        if node is not None and self.numactl:
            cmd = [self.numactl, f"--cpunodebind={node}", f"--membind={node}", "--"] + cmd
        return cmd

    def run_one(self, rnd, bench, compiler, gpu, node, order):
        c = self.compilers[compiler]
        meta = self.subset[bench]
        rec = dict(round=rnd, warmup=rnd < self.a.warmup_rounds, benchmark=bench,
                   compiler=compiler, gpu=gpu, numa=node, order=order,
                   host=socket.gethostname())
        odir = self.out / "runs" / compiler / bench
        odir.mkdir(parents=True, exist_ok=True)
        stem = odir / f"r{rnd:02d}-gpu{gpu}"
        rec["stdout"] = str(stem.with_suffix(".stdout").relative_to(self.out))
        rec["stderr"] = str(stem.with_suffix(".stderr").relative_to(self.out))
        binary, cwd = find_binary(c["tree"], c["preset"], bench, meta["binary"])
        if binary is None:
            rec.update(status="missing-binary", start=now_iso(), end=now_iso())
            return rec
        env = dict(c["env"], CUDA_VISIBLE_DEVICES=str(gpu))
        cmd = self.build_cmd(binary, meta["args"], node)
        rec["cmd"] = shlex.join(cmd)

        # Foreign GPU tenants at start of run (contention evidence for report).
        if self.a.check_tenants:
            apps = compute_apps()
            uuid = self.gpus.get(gpu, {}).get("uuid")
            if apps is not None and uuid:
                rec["foreign_procs_before"] = [a for a in apps if a[0] == uuid]

        pre = None
        if node is not None and not self.numactl:
            cpus = node_cpus(node)
            pre = lambda: os.sched_setaffinity(0, cpus)  # noqa: E731
        rec["start"] = now_iso()
        t0 = time.monotonic()
        with open(self.out / rec["stdout"], "wb") as fo, open(self.out / rec["stderr"], "wb") as fe:
            try:
                p = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=fo, stderr=fe,
                                     stdin=subprocess.DEVNULL, start_new_session=True,
                                     preexec_fn=pre)
            except OSError as e:
                rec.update(status="exec-error", error=repr(e), end=now_iso())
                return rec
            try:
                rc = p.wait(timeout=self.a.timeout)
                rec["timed_out"] = False
            except subprocess.TimeoutExpired:
                rec["timed_out"] = True
                if self.gdb:  # where was it stuck?
                    _, bt = sh([self.gdb, "-q", "-batch", "-p", str(p.pid),
                                "-ex", "thread apply all bt"], timeout=120)
                    (stem.with_suffix(".hang-bt")).write_text(bt)
                    rec["backtrace"] = str(stem.with_suffix(".hang-bt").relative_to(self.out))
                try:
                    os.killpg(p.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                rc = p.wait()
        rec["wall_s"] = time.monotonic() - t0
        rec["end"] = now_iso()
        rec["returncode"] = rc
        rec["signal"] = signal.Signals(-rc).name if rc < 0 and -rc in signal.Signals._value2member_map_ else None

        text = (self.out / rec["stdout"]).read_text(errors="replace")
        etext = (self.out / rec["stderr"]).read_text(errors="replace")
        rec["pass_lines"] = len(PASS_RE.findall(text))
        # stdout decides; stderr is informational (device-assert spew lands there).
        rec["fail_lines"] = fail_lines(text)
        rec["stderr_fail_lines"] = fail_lines(etext)
        try:
            matches = re.findall(meta["regex"], text)
            rec["matches"] = matches
            rec["value"] = sum(float(m) for m in matches) if matches else None
        except (ValueError, re.error) as e:
            rec["matches"], rec["value"], rec["parse_error"] = [], None, repr(e)

        if rec["timed_out"]:
            rec["status"] = "timeout"
        elif rc != 0:
            rec["status"] = "signal" if rc < 0 else "exit-nonzero"
        elif rec.get("parse_error"):
            rec["status"] = "parse-error"
        elif rec["fail_lines"]:
            rec["status"] = "self-fail"
        elif rec["value"] is None:
            rec["status"] = "no-match"
        else:
            rec["status"] = "ok"
        rec["stderr_tail"] = etext[-2000:] if rec["status"] != "ok" else ""
        if rec["status"] != "ok":
            rec["stdout_tail"] = text[-2000:]

        # Crash: re-run once under gdb for a backtrace.
        if self.gdb and rec["status"] == "signal":
            gcmd = [self.gdb, "-q", "-batch", "-ex", "set pagination off", "-ex", "run",
                    "-ex", "thread apply all bt", "--args"] + cmd
            _, bt = sh(gcmd, timeout=self.a.timeout, cwd=cwd, env=env)
            (stem.with_suffix(".crash-bt")).write_text(bt)
            rec["backtrace"] = str(stem.with_suffix(".crash-bt").relative_to(self.out))

        if rec["status"] in ("signal", "timeout", "exit-nonzero"):
            self.wait_gpu_idle(gpu, rec)
        return rec

    def wait_gpu_idle(self, gpu, rec, limit=60):
        """After a bad exit, don't start the next run while our GPU still has a context."""
        uuid = self.gpus.get(gpu, {}).get("uuid")
        if not uuid:
            return
        t0 = time.monotonic()
        while time.monotonic() - t0 < limit:
            apps = compute_apps()
            if apps is None or not any(a[0] == uuid for a in apps):
                return
            time.sleep(2)
        rec["gpu_busy_after"] = True

    def record(self, rec):
        line = json.dumps(rec, default=str)
        with self.lock:
            with open(self.out / "results.jsonl", "a") as f:
                f.write(line + "\n")
                f.flush()
                os.fsync(f.fileno())

    # -- scheduling ---------------------------------------------------------
    def tasks(self, benches):
        done = {}
        res = self.out / "results.jsonl"
        if self.a.resume and res.exists():
            for line in res.read_text().splitlines():
                try:
                    r = json.loads(line)
                except json.JSONDecodeError:
                    continue
                done.setdefault((r["round"], r["benchmark"]), set()).add(r["compiler"])
        total = self.a.warmup_rounds + self.a.rounds
        names = list(self.compilers)
        for rnd in range(total):
            order = list(benches)
            random.Random(self.a.seed * 1000 + rnd).shuffle(order)
            for b in order:
                if done.get((rnd, b), set()) >= set(names):
                    continue
                # Alternate which compiler goes first: ABBA across rounds, offset per benchmark.
                flip = (rnd + int(hashlib.md5(b.encode()).hexdigest(), 16)) % 2
                yield rnd, b, names[::-1] if flip else names

    def worker(self, gpu, node, q, progress):
        while not self.stop.is_set():
            try:
                rnd, bench, order = q.get_nowait()
            except queue.Empty:
                return
            for comp in order:
                if self.stop.is_set():
                    break
                try:
                    rec = self.run_one(rnd, bench, comp, gpu, node, order)
                except Exception as e:  # never let one benchmark kill the run
                    rec = dict(round=rnd, benchmark=bench, compiler=comp, gpu=gpu,
                               status="driver-error", error=repr(e), start=now_iso(), end=now_iso())
                self.record(rec)
                with self.lock:
                    progress[0] += 1
                    n, tot = progress
                print(f"[{n}/{tot}] r{rnd} gpu{gpu} {comp:6s} {bench:24s} {rec['status']:13s} "
                      f"{rec.get('value')}", flush=True)

    def run(self):
        benches = sorted(self.a.benchmarks or self.subset)
        unknown = [b for b in benches if b not in self.subset]
        if unknown:
            sys.exit(f"not in subset.json: {unknown}")
        for idx, node in self.slots:
            g = self.gpus.get(idx)
            if g and node is not None and g["numa"] is not None and g["numa"] != node:
                msg = f"GPU {idx} is attached to NUMA node {g['numa']}, not {node}"
                if not self.a.force:
                    sys.exit(msg + " (use --force to override)")
                print("WARNING:", msg, file=sys.stderr)
        self.write_meta(benches)
        tasks = list(self.tasks(benches))
        q = queue.Queue()
        for t in tasks:
            q.put(t)
        progress = [0, len(tasks) * 2]
        tele = self.start_telemetry()

        def on_signal(signum, _):
            print(f"signal {signum}: finishing current runs, then stopping "
                  "(rerun with --resume to continue)", file=sys.stderr, flush=True)
            self.stop.set()
        signal.signal(signal.SIGINT, on_signal)
        signal.signal(signal.SIGTERM, on_signal)

        threads = [threading.Thread(target=self.worker, args=(g, n, q, progress), daemon=True)
                   for g, n in self.slots]
        for t in threads:
            t.start()
        try:
            while any(t.is_alive() for t in threads):
                for t in threads:
                    t.join(timeout=1)
        finally:
            for p, f in tele:
                p.terminate()
                try:
                    p.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    p.kill()
                f.close()
        meta = json.loads((self.out / "meta.json").read_text())
        meta["finished"] = now_iso()
        meta["interrupted"] = self.stop.is_set()
        (self.out / "meta.json").write_text(json.dumps(meta, indent=1, default=str))
        print(f"done; results in {self.out}/results.jsonl. Next: {sys.argv[0]} report {self.out}")


# ----------------------------------------------------------------------------
# Preflight
# ----------------------------------------------------------------------------
def preflight(args):
    problems, notes = [], []
    gpus = gpu_table()
    if not gpus:
        sys.exit("nvidia-smi gave no GPUs")
    want = [(int(i), int(n) if n else None) for i, _, n in (g.partition(":") for g in args.gpu)]
    for idx, node in want:
        g = gpus.get(idx)
        if not g:
            problems.append(f"GPU {idx}: not present")
            continue
        if g["numa"] is not None and node is not None and g["numa"] != node:
            problems.append(f"GPU {idx}: attached to NUMA node {g['numa']}, you asked for {node}")
        if g["persistence"].lower() != "enabled":
            problems.append(f"GPU {idx}: persistence mode {g['persistence']} (sudo nvidia-smi -pm 1)")
        if "exclusive" not in g["compute_mode"].lower():
            problems.append(f"GPU {idx}: compute mode {g['compute_mode']} "
                            f"(sudo nvidia-smi -i {idx} -c EXCLUSIVE_PROCESS)")
        notes.append(f"GPU {idx} {g['name']} bus {g['bus_id']} numa {g['numa']} "
                     f"sm {g['clk_sm']}/{g['clk_sm_max']} MHz mem {g['clk_mem']} MHz")
    rc, clk = sh(["nvidia-smi", "-q", "-d", "CLOCK"])
    if "Locked" not in clk and "locked" not in clk:
        notes.append("could not confirm locked clocks from `nvidia-smi -q -d CLOCK`; "
                     "check 'Applications Clocks'/'Clock Policy' by hand")
    apps = compute_apps() or []
    uuid2idx = {g["uuid"]: i for i, g in gpus.items()}
    for uuid, pid, name in apps:
        problems.append(f"GPU {uuid2idx.get(uuid, uuid)}: busy with pid {pid} {name}")
    try:
        for line in Path("/proc/meminfo").read_text().splitlines()[:3]:
            notes.append(line)
    except OSError:
        pass
    rc, numa = sh(["numactl", "-H"])
    if rc == 0:
        frees = re.findall(r"node (\d+) free: (\d+) MB", numa)
        sizes = dict(re.findall(r"node (\d+) size: (\d+) MB", numa))
        for n, free in frees:
            if sizes.get(n) and int(free) < 0.5 * int(sizes[n]):
                problems.append(f"NUMA node {n}: only {free} of {sizes[n]} MB free (other tenants?)")
    else:
        problems.append("numactl not available: memory will not be bound (--no-membind)")
    if not shutil.which("gdb"):
        notes.append("gdb not found: --backtrace will be a no-op")
    rc, load = sh(["cat", "/proc/loadavg"])
    notes.append(f"loadavg {load.strip()}")
    for n in notes:
        print("  note:", n)
    for p in problems:
        print("  PROBLEM:", p)
    print("preflight:", "OK" if not problems else f"{len(problems)} problem(s)")
    return 1 if problems else 0


# ----------------------------------------------------------------------------
# Report
# ----------------------------------------------------------------------------
def line_sig(text, regex):
    """Split stdout into (template, numbers) for result-bearing lines.

    Lines that look like timing/perf/device-info output, or that carry the timing
    regex match, are dropped: they legitimately differ between runs."""
    out = []
    for line in text.splitlines():
        s = line.strip()
        if not s or TIMING_WORDS.search(s) or (regex and re.search(regex, s)):
            continue
        # Binaries that print their own path (argv[0]) differ only by build tree.
        s = PATH_RE.sub("<path>", s)
        nums = NUM.findall(s)
        tmpl = NUM.sub("#", s)
        out.append((tmpl, [float(x) for x in nums]))
    return out


def rel(a, b, atol):
    if a == b or (math.isnan(a) and math.isnan(b)):
        return 0.0
    if math.isnan(a) or math.isnan(b) or math.isinf(a) or math.isinf(b):
        return math.inf
    d = abs(a - b)
    if d <= atol:
        return 0.0
    return d / max(abs(a), abs(b))


def compare_outputs(ref_runs, test_runs, rtol, atol, diag_factor=10.0, diag_floor=1e-6):
    """Compare result-bearing stdout of test runs against reference runs.

    Ordinary tokens must agree within max(rtol, 2x the reference's own spread).
    Tokens on diagnostic lines (errors vs a reference, PASS/FAIL details) are
    allowed to differ, but not to get much *worse*: a test value larger than
    diag_factor x the reference's (and above diag_floor) is flagged.

    Returns (verdict, max_rel_vs_ref, max_rel_ref_self, detail)."""
    if not ref_runs or not test_runs:
        return "no-data", None, None, ""
    ref0 = ref_runs[0]
    tmpl = [t for t, _ in ref0]
    # Reference self-consistency, per token position: how much does it move by itself?
    spread = {}
    self_max = 0.0
    for r in ref_runs[1:]:
        if [t for t, _ in r] != tmpl:
            return "ref-unstable", None, None, "reference output structure varies between runs"
        for i, ((_, a), (_, b)) in enumerate(zip(ref0, r)):
            for j, (x, y) in enumerate(zip(a, b)):
                d = rel(x, y, atol)
                spread[(i, j)] = max(spread.get((i, j), 0.0), d)
                self_max = max(self_max, d)
    maxrel, worst_excess, where, diag_where = 0.0, 0.0, "", ""
    identical = True
    for r in test_runs:
        if [t for t, _ in r] != tmpl:
            a = "\n".join(tmpl[:5])
            b = "\n".join(t for t, _ in r[:5])
            return "structure-differs", None, self_max, f"ref:\n{a}\ntest:\n{b}"
        for i, ((t, a), (_, b)) in enumerate(zip(ref0, r)):
            if len(a) != len(b):
                return "structure-differs", None, self_max, f"line {i}: {t}"
            diag = bool(DIAG_WORDS.search(t))
            for j, (x, y) in enumerate(zip(a, b)):
                identical &= (x == y)
                if diag:
                    worse = (not math.isfinite(y) and math.isfinite(x)) or \
                        (abs(y) > diag_factor * abs(x) and abs(y) > diag_floor)
                    if worse and not diag_where:
                        diag_where = f"line {i} '{t}' token {j}: ref {x!r} test {y!r}"
                    continue
                d = rel(x, y, atol)
                maxrel = max(maxrel, d)
                # Allow the reference's own run-to-run wobble (e.g. atomics order).
                allowed = max(rtol, 2 * spread.get((i, j), 0.0))
                if d > allowed and d / allowed > worst_excess:
                    worst_excess = d / allowed
                    where = f"line {i} '{t}' token {j}: ref {x!r} test {y!r} (rel {d:.3g})"
    if identical:
        return "identical", 0.0, self_max, ""
    if where:
        return "differs", maxrel, self_max, where
    if diag_where:
        return "diag-worse", maxrel, self_max, diag_where
    return "within-tol", maxrel, self_max, ""


def bootstrap_ci(xs, stat, n=2000, seed=1):
    if len(xs) < 2:
        return (float("nan"), float("nan"))
    rng = random.Random(seed)
    vals = sorted(stat([rng.choice(xs) for _ in xs]) for _ in range(n))
    return vals[int(0.025 * n)], vals[int(0.975 * n) - 1]


def gmean(xs):
    xs = [x for x in xs if x > 0 and math.isfinite(x)]
    return math.exp(sum(map(math.log, xs)) / len(xs)) if xs else float("nan")


def report(args):
    out = Path(args.dir).resolve()
    meta = json.loads((out / "meta.json").read_text())
    names = list(meta["compilers"])
    ref, test = (args.reference, [n for n in names if n != args.reference][0]) \
        if args.reference else (names[0], names[1])
    recs = {}
    for line in (out / "results.jsonl").read_text().splitlines():
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        recs[(r["round"], r["benchmark"], r["compiler"])] = r  # last record wins (resume)
    # Re-derive the self-check part of the status from saved stdout, so changes to
    # the FAIL classifier apply to old results too.
    for r in recs.values():
        if r.get("status") in ("ok", "self-fail") and r.get("stdout"):
            try:
                n = fail_lines((out / r["stdout"]).read_text(errors="replace"))
            except OSError:
                continue
            r["fail_lines"] = n
            r["status"] = "self-fail" if n else "ok"
    tree = meta["compilers"][ref]["tree"]
    if (out / "meta" / "subset.json").exists():
        subset = load_subset_file(out / "meta" / "subset.json")
    elif Path(tree).exists():
        subset = load_subset(tree)
    else:
        sys.exit(f"no meta/subset.json in {out} and {tree} doesn't exist; "
                 "can't recover the benchmark regexes")
    benches = sorted({b for _, b, _ in recs})

    def text(r):
        try:
            return (out / r["stdout"]).read_text(errors="replace")
        except (OSError, KeyError):
            return ""

    rows, failures = [], []
    for b in benches:
        regex = subset.get(b, {}).get("regex", "")
        hb = bool(HIGHER_BETTER_RE.search(regex))
        per = {n: [r for (rd, bb, c), r in recs.items() if bb == b and c == n] for n in names}
        status = {n: {} for n in names}
        for n in names:
            for r in per[n]:
                status[n][r["status"]] = status[n].get(r["status"], 0) + 1
                if r["status"] != "ok":
                    failures.append(r)
        all_ok = {n: bool(per[n]) and all(r["status"] == "ok" for r in per[n]) for n in names}
        nmatch = {n: sorted({len(r.get("matches") or []) for r in per[n] if r["status"] == "ok"})
                  for n in names}
        sigs = {n: [line_sig(text(r), regex) for r in per[n] if r["status"] == "ok"] for n in names}
        verdict, maxrel, selfrel, detail = compare_outputs(sigs[ref], sigs[test], args.rtol, args.atol)
        if not (all_ok[ref] and all_ok[test]) and verdict == "no-data":
            verdict = "run-failed"
        self_checking = any(r.get("pass_lines") for n in names for r in per[n])

        correct = (all_ok[ref] and all_ok[test] and nmatch[ref] == nmatch[test]
                   and len(nmatch[ref]) == 1 and verdict in ("identical", "within-tol"))
        # Timing: paired by (round, gpu), measured rounds only, both ok, no foreign tenants.
        pairs, gpu_pairs, dropped_tenant = [], {}, 0
        for (rd, bb, c), r in recs.items():
            if bb != b or c != ref or r.get("warmup"):
                continue
            t = recs.get((rd, b, test))
            if not t or r["status"] != "ok" or t["status"] != "ok" or r["gpu"] != t["gpu"]:
                continue
            if r.get("foreign_procs_before") or t.get("foreign_procs_before"):
                dropped_tenant += 1
                continue
            a, c2 = r["value"], t["value"]
            if not a or not c2:
                continue
            ratio = (a / c2) if hb else (c2 / a)  # >1 = test slower
            pairs.append(ratio)
            gpu_pairs.setdefault(r["gpu"], []).append(ratio)

        def cv(n):
            v = [r["value"] for r in per[n] if r["status"] == "ok" and not r.get("warmup") and r["value"]]
            return (st.pstdev(v) / st.mean(v)) if len(v) > 1 and st.mean(v) else float("nan")
        med = st.median(pairs) if pairs else float("nan")
        lo, hi = bootstrap_ci(pairs, st.median)
        rows.append(dict(
            benchmark=b, correct=correct, output_verdict=verdict,
            max_rel_diff=maxrel, ref_self_rel=selfrel, self_checking=self_checking,
            status_ref=status[ref], status_test=status[test],
            matches_ref=nmatch[ref], matches_test=nmatch[test],
            n_pairs=len(pairs), dropped_tenant=dropped_tenant, ratio_median=med, ci_lo=lo, ci_hi=hi,
            cv_ref=cv(ref), cv_test=cv(test), higher_is_better=hb,
            per_gpu={g: st.median(v) for g, v in sorted(gpu_pairs.items())},
            detail=detail))

    # Device effect: per GPU, ref value / that benchmark's ref median across all GPUs.
    dev = {}
    for b in benches:
        vals = [(r["gpu"], r["value"]) for (rd, bb, c), r in recs.items()
                if bb == b and c == ref and r["status"] == "ok" and not r.get("warmup") and r["value"]]
        if len(vals) < 3:
            continue
        m = st.median(v for _, v in vals)
        for g, v in vals:
            dev.setdefault(g, []).append(v / m)

    # ---- write outputs ----
    import csv
    with open(out / "report.csv", "w", newline="") as f:
        cols = ["benchmark", "correct", "output_verdict", "max_rel_diff", "ref_self_rel",
                "self_checking", "status_ref", "status_test", "matches_ref", "matches_test",
                "n_pairs", "dropped_tenant", "ratio_median", "ci_lo", "ci_hi", "cv_ref", "cv_test",
                "higher_is_better", "per_gpu", "detail"]
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow({k: (json.dumps(v) if isinstance(v, (dict, list)) else v) for k, v in r.items()})

    good = [r for r in rows if r["correct"] and r["n_pairs"] >= args.min_pairs]
    ratios = [r["ratio_median"] for r in good]
    L = []
    p = L.append
    p(f"# Paired HeCBench report: {test} vs {ref} (ratio > 1 = {test} slower)\n")
    p(f"- results: `{out}`; host {meta.get('host')}; slots {meta.get('slots')}; "
      f"rounds {meta.get('rounds')} (+{meta.get('warmup_rounds')} warm-up)")
    p(f"- correctness: rtol={args.rtol}, atol={args.atol}; timing needs >= {args.min_pairs} clean pairs\n")
    p("## Correctness")
    from collections import Counter
    p(f"- output verdicts: {dict(Counter(r['output_verdict'] for r in rows))}")
    p(f"- correct on both sides: {sum(r['correct'] for r in rows)} / {len(rows)}")
    bad = [r for r in rows if not r["correct"]]
    if bad:
        p("\n| benchmark | verdict | max rel diff | ref self-spread | ref statuses | test statuses | matches ref/test | detail |")
        p("|---|---|---|---|---|---|---|---|")
        for r in bad:
            p(f"| {r['benchmark']} | {r['output_verdict']} | {r['max_rel_diff']} | {r['ref_self_rel']} | "
              f"{r['status_ref']} | {r['status_test']} | {r['matches_ref']}/{r['matches_test']} | "
              f"{(r['detail'] or '').replace('|', '/').replace(chr(10), ' ')[:160]} |")
    p("\n## Timing (correct benchmarks only)")
    dt_ = sum(r["dropped_tenant"] for r in rows)
    if dt_:
        p(f"- **{dt_} pairs dropped because another process held the GPU** "
          f"(see telemetry/apps.csv): {[r['benchmark'] for r in rows if r['dropped_tenant']]}")
    if ratios:
        lo, hi = bootstrap_ci(ratios, gmean)
        p(f"- n={len(good)}; geomean ratio {gmean(ratios):.3f} (95% CI {lo:.3f}-{hi:.3f}); "
          f"median {st.median(ratios):.3f}")
        sig = [r for r in good if r["ci_lo"] > 1 + args.margin or r["ci_hi"] < 1 - args.margin]
        p(f"- significant (CI excludes 1±{args.margin}): {len(sig)} "
          f"({sum(r['ci_lo'] > 1 for r in sig)} {test}-slower, {sum(r['ci_hi'] < 1 for r in sig)} {test}-faster)")
        noisy = [r["benchmark"] for r in good if max(r["cv_ref"], r["cv_test"]) > 0.05]
        p(f"- noisy (CV > 5% on either side after cleaning): {noisy}")
        p("\n| benchmark | ratio | 95% CI | pairs | CV ref | CV test | per-GPU |")
        p("|---|---|---|---|---|---|---|")
        for r in sorted(good, key=lambda r: r["ratio_median"]):
            p(f"| {r['benchmark']} | {r['ratio_median']:.3f} | {r['ci_lo']:.3f}-{r['ci_hi']:.3f} | "
              f"{r['n_pairs']} | {r['cv_ref']:.3f} | {r['cv_test']:.3f} | "
              f"{', '.join(f'{g}:{v:.3f}' for g, v in r['per_gpu'].items())} |")
    else:
        p("- no benchmark had enough clean, correct pairs")
    p("\n## Device effect (ref compiler: per-GPU value / cross-GPU median)")
    for g, v in sorted(dev.items()):
        p(f"- GPU {g}: geomean {gmean(v):.4f} over {len(v)} samples")
    p(f"\n## Failures ({len(failures)} runs) — see failures.md")
    (out / "report.md").write_text("\n".join(L) + "\n")

    # Group identical failures (same benchmark/compiler/status) and show the first in full.
    groups = {}
    for r in sorted(failures, key=lambda r: (r["benchmark"], r["compiler"], r["round"])):
        groups.setdefault((r["benchmark"], r["compiler"], r["status"]), []).append(r)
    with open(out / "failures.md", "w") as f:
        f.write(f"# Failed runs ({len(failures)} runs in {len(groups)} groups)\n\n")
        for (b, comp, status), rs in groups.items():
            r = rs[0]
            where = ", ".join(f"r{x['round']}/gpu{x.get('gpu')}" for x in rs)
            f.write(f"## {b} [{comp}]: {status} x{len(rs)}\n\n- runs: {where}\n")
            f.write(f"- cmd: `{r.get('cmd')}`\n- returncode {r.get('returncode')} signal {r.get('signal')} "
                    f"timed_out {r.get('timed_out')} wall {r.get('wall_s')}\n"
                    f"- matches {r.get('matches')} pass_lines {r.get('pass_lines')} "
                    f"fail_lines {r.get('fail_lines')}\n- stdout `{r.get('stdout')}` stderr `{r.get('stderr')}`\n")
            if r.get("error"):
                f.write(f"- driver error: `{r['error']}`\n")
            for k in ("stdout_tail", "stderr_tail"):
                if r.get(k):
                    f.write(f"\n{k}:\n```\n{r[k][-1500:]}\n```\n")
            if r.get("backtrace"):
                try:
                    bt = (out / r["backtrace"]).read_text(errors="replace")
                    f.write(f"\nbacktrace:\n```\n{bt[-4000:]}\n```\n")
                except OSError:
                    pass
            f.write("\n")
    print((out / "report.md").read_text())
    return 0


# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    pf = sub.add_parser("preflight", help="check GPU/NUMA/tenancy before running")
    pf.add_argument("--gpu", action="append", required=True, metavar="IDX:NODE")

    rp = sub.add_parser("run", help="run paired benchmarks")
    rp.add_argument("--out", required=True, help="results directory (created)")
    rp.add_argument("--compiler", action="append", required=True,
                    metavar="NAME=TREE:TOOLKIT[:PRESET]",
                    help="e.g. nvcc=/home/u/bench-nvcc/HeCBench/HeCBench:/usr/local/cuda-13.0. "
                         "TREE is the HeCBench checkout containing build/PRESET (PRESET defaults "
                         "to --preset). Give exactly two; the first is the reference in reports.")
    rp.add_argument("--gpu", action="append", required=True, metavar="IDX:NODE",
                    help="GPU index (nvidia-smi/PCI order) and its local NUMA node. Repeat for "
                         "parallel workers, e.g. --gpu 0:1 --gpu 4:5")
    rp.add_argument("--arch", default="sm_103")
    rp.add_argument("--preset", default="scale-cuda-sm103")
    rp.add_argument("--rounds", type=int, default=10, help="measured rounds (default 10)")
    rp.add_argument("--warmup-rounds", type=int, default=1)
    rp.add_argument("--timeout", type=int, default=600, help="per-run seconds (runner default)")
    rp.add_argument("--benchmarks", nargs="*", help="subset of subset.json names (default: all)")
    rp.add_argument("--env", action="append", default=[], metavar="[NAME:]K=V",
                    help="set env for both compilers, or only NAME's, e.g. "
                         "CUDA_MODULE_LOADING=EAGER")
    rp.add_argument("--env-prepend", action="append", default=[], metavar="[NAME:]K=V",
                    help="prepend a path to an env var, e.g. "
                         "scale:LD_LIBRARY_PATH=/opt/scale/llvm/lib/x86_64-unknown-linux-gnu")
    rp.add_argument("--seed", type=int, default=1)
    rp.add_argument("--resume", action="store_true", help="skip tasks already in results.jsonl")
    rp.add_argument("--backtrace", action="store_true", help="gdb backtraces on crashes/hangs")
    rp.add_argument("--no-membind", action="store_true", help="don't use numactl; affinity only")
    rp.add_argument("--no-telemetry", action="store_true")
    rp.add_argument("--telemetry-ms", type=int, default=500)
    rp.add_argument("--no-check-tenants", dest="check_tenants", action="store_false",
                    help="skip the per-run nvidia-smi check for foreign GPU processes")
    rp.add_argument("--force", action="store_true", help="allow GPU/NUMA mismatches")

    rr = sub.add_parser("report", help="correctness + timing report")
    rr.add_argument("dir")
    rr.add_argument("--reference", help="reference compiler name (default: first)")
    rr.add_argument("--rtol", type=float, default=1e-4,
                    help="relative tolerance on result values (default 1e-4 = 0.01%%); widened "
                         "per value to 2x the reference's own run-to-run spread")
    rr.add_argument("--atol", type=float, default=1e-12)
    rr.add_argument("--min-pairs", type=int, default=5)
    rr.add_argument("--margin", type=float, default=0.03,
                    help="a ratio is significant if its CI excludes 1±margin")

    a = ap.parse_args()
    if a.cmd == "preflight":
        return preflight(a)
    if a.cmd == "run":
        Runner(a).run()
        return 0
    return report(a)


if __name__ == "__main__":
    sys.exit(main())
