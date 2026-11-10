"""bench.py: GPU time of single PyTorch ops: what vLLM calls through torch (the sampler's logits cast, strided copies)
and what the HuggingFace inductor models fall back to (elementwise, casts, norms, softmax, index, cat).

Each op is captured 200 times into a CUDA graph and the graph is replayed, so the kernel's time shows rather than the
launch floor. Prints CSV: case,role,us (best of ROUNDS replays, microseconds per op). role is "gap" for the shapes
where SCALE is known to be slower than nvcc (softmax 4096x1024: registers; layer_norm 64x50272: load batching) and
"op" otherwise. With RESULTS_DIR set (benchmark.py) the CSV is also written to
RESULTS_DIR/pytorch-ops.<compiler>.<arch>.r<repeat>.<time>.csv.
"""

import datetime
import os
import sys

import torch
import torch.nn.functional as F

COPIES = 200
ROUNDS = 20
BF16, F32 = torch.bfloat16, torch.float32
GAPS = {"softmax 4096x1024", "layer_norm 64x50272"}


def ops():
    """[(case name, CPU inputs, function)]; the inputs move to the GPU as they are, bf16 unless noted."""
    out = []

    def t(*shape, dtype=BF16):
        return torch.randn(*shape, dtype=dtype)

    for n in (151936, 16 * 151936):
        out.append((f"cast_bf16_f32 {n}", [t(n // 151936, 151936)], lambda x: x.float()))
    for n in (4096, 65536, 1 << 20, 1 << 24):
        a, b, af = t(n), t(n), t(n, dtype=F32)
        out += [(f"add_bf16 {n}", [a, b], lambda a, b: a + b),
                (f"mul_scalar_bf16 {n}", [a], lambda a: a * 0.5),
                (f"gelu_bf16 {n}", [a], F.gelu),
                (f"silu_bf16 {n}", [a], F.silu),
                (f"add_f32 {n}", [af], lambda a: a + a),
                (f"cast_f32_bf16 {n}", [af], lambda a: a.to(BF16))]
    for tok in (16, 256, 4096):
        out += [(f"copy_strided_bf16 t{tok}", [t(tok, 2, 4096)], lambda x: x[:, 0].contiguous()),
                (f"copy_strided_f32 t{tok}", [t(tok, 2, 4096, dtype=F32)], lambda x: x[:, 0].contiguous()),
                (f"transpose_copy t{tok}", [t(tok, 4096)], lambda y: y.t().contiguous())]
    for rows, cols in ((16, 768), (512, 768), (4096, 1024), (64, 50272)):
        x = t(rows, cols)
        out += [(f"layer_norm {rows}x{cols}", [x, t(cols), t(cols)],
                 lambda x, w, b: F.layer_norm(x, x.shape[-1:], w, b)),
                (f"softmax {rows}x{cols}", [x], lambda x: torch.softmax(x, -1)),
                (f"sum_rows {rows}x{cols}", [x], lambda x: x.sum(-1)),
                (f"argmax_rows {rows}x{cols}", [x], lambda x: x.argmax(-1))]
    for vocab, dim, n in ((50272, 768, 512), (151936, 4096, 16)):
        w, idx = t(vocab, dim), torch.randint(0, vocab, (n,))
        out += [(f"embedding {vocab}x{dim} n{n}", [idx, w], F.embedding),
                (f"index_select {vocab}x{dim} n{n}", [w, idx], lambda w, idx: w.index_select(0, idx))]
    x = t(8, 512, 768)
    out += [("cat_dim1 8x512x768", [x], lambda x: torch.cat([x, x], 1)),
            ("where 8x512x768", [x], lambda x: torch.where(x > 0, x, 0.0)),
            ("masked_fill 8x512x768", [x], lambda x: x.masked_fill(x > 0, -1e4)),
            ("fill 1<<24", [t(1 << 24)], lambda x: x.zero_())]
    return out


def cases():
    """(case name, role, GPU inputs, function) for each op."""
    for name, inputs, fn in ops():
        yield name, "gap" if name in GAPS else "op", [x.to("cuda") for x in inputs], fn


def time_us(fn):
    for _ in range(3):
        fn()
    torch.cuda.synchronize()
    graph = torch.cuda.CUDAGraph()
    stream = torch.cuda.Stream()
    with torch.cuda.stream(stream):
        fn()
        with torch.cuda.graph(graph, stream=stream):
            for _ in range(COPIES):
                fn()
    torch.cuda.synchronize()
    start, end = torch.cuda.Event(enable_timing=True), torch.cuda.Event(enable_timing=True)
    best = float("inf")
    for _ in range(ROUNDS):
        graph.replay()
        start.record()
        graph.replay()
        end.record()
        end.synchronize()
        best = min(best, start.elapsed_time(end) * 1000 / COPIES)
    return best


def bench():
    lines = ["case,role,us"]
    print(lines[0])
    for name, role, gpu, fn in cases():
        lines.append(f"{name},{role},{time_us(lambda: fn(*gpu)):.3f}")
        print(lines[-1], flush=True)
    if os.environ.get("RESULTS_DIR"):
        env = os.environ.get
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M%SZ")
        name = (f"pytorch-ops.{env('BENCHMARK_COMPILER', 'unknown')}.{env('TEST_GPU_ARCH', 'unknown')}"
                f".r{env('BENCHMARK_REPEAT', '1')}.{stamp}.csv")
        with open(os.path.join(env("RESULTS_DIR"), name), "w") as f:
            f.write("\n".join(lines) + "\n")


def main():
    assert not sys.argv[1:], "usage: bench.py"
    assert torch.version.hip is None, "expected a CUDA build of PyTorch"
    assert torch.cuda.is_available(), "no GPU visible to PyTorch"
    print(f"# torch {torch.__version__}, {torch.cuda.get_device_name()}", file=sys.stderr)
    torch.manual_seed(0)
    bench()


if __name__ == "__main__":
    main()
