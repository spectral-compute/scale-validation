# SGLang serving settings that avoid Triton and CuTe DSL kernels, which can't
# run under SCALE (both emit NVIDIA binaries). Source after activating the venv;
# pass "${triton_free_server_args[@]}" to the server.

# FlashInfer's CUDA norms rather than its CuTe DSL ones.
export FLASHINFER_USE_CUDA_NORM=1

# The eager runner copies its inputs with a Triton kernel unless this is set.
export SGLANG_EAGER_INPUT_NO_COPY=1

# torch's own Triton (and CuTe DSL) implementations of some ops, which it
# otherwise prefers for e.g. matmuls inside attention.
export TORCH_DISABLE_NATIVE_JIT=1

# Make torch.compile a no-op, so nothing reaches Inductor, which generates
# Triton (e.g. the repetition penalty).
export TORCHDYNAMO_DISABLE=1

# torch_native attention avoids the Triton KV-index, req_to_token and position
# kernels that the other backends use (and turns CUDA graphs off). It gathers
# each request's KV into new tensors, outside the KV cache's memory, so leave
# more of the GPU for those. Sampling and grammar backends kept to ones that
# don't use Triton.
# shellcheck disable=SC2034 # used by the scripts that source this
triton_free_server_args=(
    --attention-backend torch_native
    --mem-fraction-static 0.7
    --sampling-backend pytorch
    --grammar-backend none
)
