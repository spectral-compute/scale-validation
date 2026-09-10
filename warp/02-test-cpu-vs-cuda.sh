#!/bin/bash

set -ETeuo pipefail

cd warp
source venv/bin/activate

# Integrates a batch of particles under gravity plus a couple of nonlinear
# forces (quadratic drag, a sinusoidal side force) for a few hundred steps,
# once on the "cpu" device and once on "cuda:0" (SCALE, via
# --use-dynamic-cuda's dlopen'd libcuda.so). Both runs start from the same
# seeded input and use the same kernel, so -- like cycles' CPU-vs-CUDA render
# comparison -- any real codegen/runtime bug on the CUDA path (wrong builtin,
# bad memory layout, broken atomics, etc.) should show up as a large
# divergence between the two trajectories, while the residual float
# rounding/reduction-order noise between backends stays tiny. On real
# hardware (CPU vs. an NVIDIA GPU, sanity-checked without SCALE) the
# resulting MSE was ~1e-12 -- MSE_THRESHOLD below is ~1e6x looser than that,
# so it won't fire on backend rounding noise but will still catch a
# genuinely broken CUDA path.
python3 - <<'PYEOF'
import sys

import numpy as np
import warp as wp

wp.init()

NUM_PARTICLES = 4096
NUM_STEPS = 500
DT = 1.0 / 240.0
GRAVITY = wp.vec3(0.0, -9.8, 0.0)
MSE_THRESHOLD = 1e-6


@wp.kernel
def integrate_particles(
    positions: wp.array(dtype=wp.vec3),
    velocities: wp.array(dtype=wp.vec3),
    gravity: wp.vec3,
    dt: float,
):
    tid = wp.tid()

    x = positions[tid]
    v = velocities[tid]

    # Nonlinear terms (quadratic drag + a sinusoidal side force) so the
    # kernel exercises more than trivial arithmetic in codegen.
    speed = wp.length(v)
    drag = -0.01 * speed * v
    side_force = wp.vec3(wp.sin(x[1] * 4.0), 0.0, wp.cos(x[0] * 4.0)) * 0.5

    v_new = v + (gravity + drag + side_force) * dt
    x_new = x + v_new * dt

    velocities[tid] = v_new
    positions[tid] = x_new


def run(device):
    rng = np.random.default_rng(42)
    x0 = rng.uniform(-1.0, 1.0, size=(NUM_PARTICLES, 3)).astype(np.float32)
    v0 = rng.uniform(-0.5, 0.5, size=(NUM_PARTICLES, 3)).astype(np.float32)

    with wp.ScopedDevice(device):
        positions = wp.array(x0, dtype=wp.vec3)
        velocities = wp.array(v0, dtype=wp.vec3)

        for _ in range(NUM_STEPS):
            wp.launch(
                kernel=integrate_particles,
                dim=NUM_PARTICLES,
                inputs=[positions, velocities, GRAVITY, DT],
            )

        wp.synchronize_device(device)
        return positions.numpy(), velocities.numpy()


if not wp.is_cuda_available():
    print("FAILED: no CUDA device available -- SCALE's libcuda.so was not picked up")
    sys.exit(1)

cpu_x, cpu_v = run("cpu")
if not np.all(np.isfinite(cpu_x)) or not np.all(np.isfinite(cpu_v)):
    print("FAILED: non-finite values in the CPU reference run")
    sys.exit(1)

cuda_x, cuda_v = run("cuda:0")
if not np.all(np.isfinite(cuda_x)) or not np.all(np.isfinite(cuda_v)):
    print("FAILED: non-finite values in the CUDA run")
    sys.exit(1)

mse_x = float(np.mean((cpu_x - cuda_x) ** 2))
mse_v = float(np.mean((cpu_v - cuda_v) ** 2))
print(f"position MSE (cpu vs. cuda): {mse_x:.3e} (threshold {MSE_THRESHOLD:.3e})")
print(f"velocity MSE (cpu vs. cuda): {mse_v:.3e} (threshold {MSE_THRESHOLD:.3e})")

if mse_x >= MSE_THRESHOLD or mse_v >= MSE_THRESHOLD:
    print("FAILED: cpu and cuda trajectories diverged beyond the threshold")
    sys.exit(1)

print("PASSED: cpu and cuda trajectories agree")
PYEOF
