"""Time the ppisp extension's kernels: forward, backward and the regularization loss.

Prints CSV: case,resolution,us (mean time per call, best of several timed rounds).
"""

import sys

import torch

import ppisp_cuda

NUM_CAMERAS = 3
NUM_FRAMES = 500
RESOLUTIONS = [(960, 540), (1920, 1080), (3840, 2160)]
ROUNDS = 7


def time_us(fn, iters):
    for _ in range(3):
        fn()
    torch.cuda.synchronize()
    best = float("inf")
    for _ in range(ROUNDS):
        start = torch.cuda.Event(enable_timing=True)
        end = torch.cuda.Event(enable_timing=True)
        start.record()
        for _ in range(iters):
            fn()
        end.record()
        end.synchronize()
        best = min(best, start.elapsed_time(end) * 1000 / iters)
    return best


def main():
    torch.manual_seed(0)
    dev = "cuda"
    exposure = torch.empty(NUM_FRAMES, device=dev).uniform_(-0.5, 0.5)
    vignetting = torch.empty(NUM_CAMERAS, 3, 5, device=dev).uniform_(-0.1, 0.1)
    color = torch.empty(NUM_FRAMES, 8, device=dev).uniform_(-0.1, 0.1)
    crf = torch.empty(NUM_CAMERAS, 3, 4, device=dev).uniform_(-0.5, 0.5)
    params = (exposure, vignetting, color, crf)

    print("case,resolution,us")
    for w, h in RESOLUTIONS:
        rgb = torch.empty(h * w, 3, device=dev).uniform_(0.1, 0.9)
        grad = torch.randn(h * w, 3, device=dev)
        coords = torch.stack(torch.meshgrid(torch.arange(w, device=dev) + 0.5,
                                            torch.arange(h, device=dev) + 0.5,
                                            indexing="xy"), dim=-1).reshape(-1, 2).contiguous()
        iters = max(10, 2 * 3840 * 2160 // (w * h) * 10)
        for name, pc in (("", None), ("_coords", coords)):
            fwd = time_us(lambda: ppisp_cuda.ppisp_forward(*params, rgb, pc, w, h, 1, 7), iters)
            print(f"forward{name},{w}x{h},{fwd:.1f}")
            bwd = time_us(lambda: ppisp_cuda.ppisp_backward(*params, rgb, pc, grad, w, h, 1, 7),
                          iters)
            print(f"backward{name},{w}x{h},{bwd:.1f}")
        sys.stdout.flush()

    weights = (1.0, 0.02, 0.02, 0.02, 1.0, 0.02)
    loss, sums = ppisp_cuda.ppisp_regularization_forward(*params, *weights)
    one = torch.ones((), device=dev)
    reg_fwd = time_us(lambda: ppisp_cuda.ppisp_regularization_forward(*params, *weights), 200)
    print(f"regularization_forward,-,{reg_fwd:.1f}")
    reg_bwd = time_us(
        lambda: ppisp_cuda.ppisp_regularization_backward(*params, one, sums, *weights), 200)
    print(f"regularization_backward,-,{reg_bwd:.1f}")


if __name__ == "__main__":
    main()
