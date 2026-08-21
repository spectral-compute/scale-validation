#!/usr/bin/env bash
set -euo pipefail

# This script tests PyTorch datatypes by training two small models on MNIST data with
# three different precisions. We check the training curve follows "roughly  the right
# shape" (defined via `EXPECTATIONS`). The script exits with 0 if and only if it runs
# to completion (with all precisions) and our criterion for the training curve
# following the right shape is satisfied.


# TODO(#1144): Kill.
#
# Pytorch tries to use and other GPUs leading to errors.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"


# PyTorch's addmm uses cuBLASLt, which SCALE does not support yet. Without this the
# TF32 runs fail with:
#   RuntimeError: CUDA error: CUBLAS_STATUS_NOT_SUPPORTED when calling
#   `cublasLtMatmulDescCreate(&raw_descriptor, compute_type, scale_type)`
# This makes PyTorch fall back to plain cuBLAS.
export DISABLE_ADDMM_CUDA_LT=1


source pytorch/.venv/bin/activate

python -u - <<'PY'
import contextlib
import os
import sys
import time

import torch
from torch import nn
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

# Define the datatypes to use here
PRECISIONS = ("fp32", "tf32", "amp-bf16")

EPOCHS = 5
SEED = 0

# The per-epoch accuracy thresholds are a rising sequence: clearing all of
# them means the curve climbed with roughly the right shape. Calibrated on
# real GPU runs across every model x precision combination, then loosened to
# absorb non-determinism and toolchain differences.
EXPECTATIONS = {
    "mlp": {
        "max_initial_acc": 0.20,
        "min_acc_at_epoch": {1: 0.90, 3: 0.94, 5: 0.95},
        "max_final_loss": 0.15,
    },
    "cnn": {
        "max_initial_acc": 0.20,
        "min_acc_at_epoch": {1: 0.95, 3: 0.97, 5: 0.98},
        "max_final_loss": 0.10,
    },
}

# How far accuracy may dip between checkpoints and still count as
# "non-decreasing" (epoch-to-epoch noise on a plateau).
MONOTONIC_TOL = 0.02

failures = []


def check(ok, message):
    if not ok:
        failures.append(message)
        print(f"FAIL: {message}")


def build_model(name):
    if name == "mlp":
        return nn.Sequential(
            nn.Flatten(),
            nn.Linear(28 * 28, 256), nn.ReLU(),
            nn.Linear(256, 256), nn.ReLU(),
            nn.Linear(256, 10),
        )
    # A small LeNet-style CNN; the convolutions give broader kernel coverage.
    return nn.Sequential(
        nn.Conv2d(1, 32, 3, padding=1), nn.ReLU(), nn.MaxPool2d(2),
        nn.Conv2d(32, 64, 3, padding=1), nn.ReLU(), nn.MaxPool2d(2),
        nn.Flatten(),
        nn.Linear(64 * 7 * 7, 128), nn.ReLU(), nn.Dropout(0.25),
        nn.Linear(128, 10),
    )


def dataloaders():
    transform = transforms.Compose(
        [transforms.ToTensor(), transforms.Normalize((0.1307,), (0.3081,))]
    )
    train_set = datasets.MNIST("data", train=True, download=True, transform=transform)
    test_set = datasets.MNIST("data", train=False, download=True, transform=transform)
    return (
        DataLoader(train_set, batch_size=128, shuffle=True, pin_memory=True),
        DataLoader(test_set, batch_size=512, pin_memory=True),
    )


def autocast(precision):
    if precision == "amp-bf16":
        return torch.autocast("cuda", dtype=torch.bfloat16)
    return contextlib.nullcontext()


@torch.no_grad()
def evaluate(model, loader, precision):
    model.eval()
    criterion = nn.CrossEntropyLoss(reduction="sum")
    total_loss, correct, total = 0.0, 0, 0
    for inputs, targets in loader:
        inputs, targets = inputs.cuda(), targets.cuda()
        with autocast(precision):
            outputs = model(inputs)
            total_loss += criterion(outputs, targets).item()
        correct += (outputs.argmax(dim=1) == targets).sum().item()
        total += targets.size(0)
    return total_loss / total, correct / total


def train(model_name, precision, train_loader, test_loader):
    """Return the untrained (loss, acc) and the per-epoch [(loss, acc)] curve."""

    # Configure the backend
    tf32 = precision == "tf32"
    torch.backends.cuda.matmul.allow_tf32 = tf32
    torch.backends.cudnn.allow_tf32 = tf32
    torch.set_float32_matmul_precision("high" if tf32 else "highest")


    torch.manual_seed(SEED)
    torch.cuda.manual_seed_all(SEED)

    model = build_model(model_name).cuda()
    optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
    criterion = nn.CrossEntropyLoss()

    initial = evaluate(model, test_loader, precision)
    print(f"[{model_name}/{precision}] epoch 0 loss={initial[0]:.4f} acc={initial[1]:.4f} (untrained)")

    curve = []
    for epoch in range(1, EPOCHS + 1):
        model.train()
        for inputs, targets in train_loader:
            inputs, targets = inputs.cuda(), targets.cuda()
            optimizer.zero_grad(set_to_none=True)
            with autocast(precision):
                loss = criterion(model(inputs), targets)
            loss.backward()
            optimizer.step()
        test_loss, test_acc = evaluate(model, test_loader, precision)
        curve.append((test_loss, test_acc))
        print(f"[{model_name}/{precision}] epoch {epoch} loss={test_loss:.4f} acc={test_acc:.4f}")

    return initial, curve


def check_curve(model_name, precision, initial, curve):
    spec = EXPECTATIONS[model_name]
    who = f"{model_name}/{precision}"
    initial_loss, initial_acc = initial
    acc_at = {epoch: curve[epoch - 1][1] for epoch in spec["min_acc_at_epoch"]}
    final_loss = curve[-1][0]

    # The untrained network should score near chance (~10%).
    check(initial_acc < spec["max_initial_acc"],
          f"{who}: untrained accuracy {initial_acc:.4f} is too high to be a fresh network")

    # Accuracy must clear the rising thresholds and jump well above chance.
    for epoch, threshold in sorted(spec["min_acc_at_epoch"].items()):
        check(acc_at[epoch] >= threshold,
              f"{who}: accuracy at epoch {epoch} was {acc_at[epoch]:.4f}, below {threshold:.2f}")
    first_epoch = min(spec["min_acc_at_epoch"])
    check(acc_at[first_epoch] - initial_acc > 0.5,
          f"{who}: accuracy barely moved ({initial_acc:.4f} -> {acc_at[first_epoch]:.4f}); "
          "training is not learning")

    # Later checkpoints must not fall meaningfully below earlier ones.
    epochs = sorted(spec["min_acc_at_epoch"])
    for earlier, later in zip(epochs, epochs[1:]):
        check(acc_at[later] >= acc_at[earlier] - MONOTONIC_TOL,
              f"{who}: accuracy fell from {acc_at[earlier]:.4f} (epoch {earlier}) "
              f"to {acc_at[later]:.4f} (epoch {later})")

    # Test loss should fall well below its untrained value.
    check(final_loss < initial_loss,
          f"{who}: final loss {final_loss:.4f} did not improve on the untrained {initial_loss:.4f}")
    check(final_loss < spec["max_final_loss"],
          f"{who}: final loss {final_loss:.4f} exceeds the {spec['max_final_loss']:.2f} ceiling")


# Fail if CUDA is not available to prevent a silent fall-back to the CPU
if not torch.cuda.is_available():
    sys.exit("torch.cuda.is_available() is False; there is no GPU path to test.")
print(f"Device: {torch.cuda.get_device_name(0)}")


# Quick check that GPU kernels produce roughly the same result as CPU before we start training
torch.manual_seed(SEED)
a, b = torch.randn(256, 256), torch.randn(256, 256)
if not torch.allclose(a @ b, (a.cuda() @ b.cuda()).cpu(), atol=1e-3, rtol=1e-3):
    sys.exit("GPU matmul does not match the CPU result.")

# Constructing the datasets downloads MNIST on first use, so start the clock
# after this line to keep the (network-dependent) download out of the timing.
train_loader, test_loader = dataloaders()

time_start = time.perf_counter()
for model_name in EXPECTATIONS:
    for precision in PRECISIONS:
        initial, curve = train(model_name, precision, train_loader, test_loader)
        check_curve(model_name, precision, initial, curve)
elapsed = time.perf_counter() - time_start

# Record the training+evaluation time in the build artifacts, whether or not
# the curve checks passed.
print(f"\nTotal training+evaluation time: {elapsed:.3f} seconds")
os.makedirs("/tmp/ci_benchmarks", exist_ok=True)
with open("/tmp/ci_benchmarks/datatypetests.txt", "w") as f:
    f.write(f"training_seconds={elapsed:.3f}\n")

if failures:
    print(f"\n{len(failures)} check(s) failed:")
    for message in failures:
        print(f"  - {message}")
    sys.exit(1)
print("\nAll model/datatype training curves have the expected shape.")
PY
