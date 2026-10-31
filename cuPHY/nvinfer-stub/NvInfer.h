// The subset of TensorRT's API cuPHY's trt_engine uses. TensorRT doesn't exist for AMD, so
// createInferRuntime() always fails, as it would without a usable TensorRT. The same stub is used
// under NVIDIA CUDA, so both toolchains run (and skip) the same TensorRT-dependent paths.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cuda_runtime_api.h>

namespace nvinfer1 {

class ILogger {
public:
    enum class Severity : int32_t { kINTERNAL_ERROR = 0, kERROR = 1, kWARNING = 2, kINFO = 3, kVERBOSE = 4 };
    virtual void log(Severity severity, const char* msg) noexcept = 0;
    virtual ~ILogger() = default;
};

struct Dims {
    static constexpr int32_t MAX_DIMS = 8;
    int32_t nbDims;
    int64_t d[MAX_DIMS];
};

class IExecutionContext {
public:
    virtual ~IExecutionContext() noexcept = default;
    virtual bool setTensorAddress(const char* name, void* data) noexcept = 0;
    virtual bool setInputShape(const char* name, const Dims& dims) noexcept = 0;
    virtual bool allInputDimensionsSpecified() const noexcept = 0;
    virtual bool enqueueV3(cudaStream_t stream) noexcept = 0;
};

class ICudaEngine {
public:
    virtual ~ICudaEngine() noexcept = default;
    virtual IExecutionContext* createExecutionContext() noexcept = 0;
};

class IRuntime {
public:
    virtual ~IRuntime() noexcept = default;
    virtual ICudaEngine* deserializeCudaEngine(const void* blob, std::size_t size) noexcept = 0;
};

IRuntime* createInferRuntime(ILogger& logger) noexcept;

} // namespace nvinfer1
