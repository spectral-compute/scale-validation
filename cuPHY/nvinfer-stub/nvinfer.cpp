#include "NvInfer.h"

nvinfer1::IRuntime* nvinfer1::createInferRuntime(ILogger& logger) noexcept
{
    logger.log(ILogger::Severity::kERROR, "TensorRT is not available (scale-validation stub)");
    return nullptr;
}
