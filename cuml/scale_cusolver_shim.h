// Shim for SCALE 1.7.1 cusolver gaps, force-included before raft headers.
//
// SCALE's cusolverDn.h is missing several things that raft's
// cusolver_wrappers.hpp depends on at parse time:
//   1. The CUSOLVERAPI calling-convention macro (NVIDIA defines it empty).
//   2. The cusolverEigRange_t enum (selective-eigensolver range mode).
//   3. The selective symmetric eigensolver API: cusolverDn{S,D}syevdx[_bufferSize].
//      SCALE provides full eig (syevd/syevj) but not the selective variant.
//      These declarations only need to exist for name lookup; PCA/tSVD/GLM use
//      full eig, so the syevdx symbols are not actually linked.
#pragma once
#include <cusolverDn.h>

#ifndef CUSOLVERAPI
#define CUSOLVERAPI
#endif

#ifndef SCALE_CUSOLVER_EIGRANGE_SHIM
#define SCALE_CUSOLVER_EIGRANGE_SHIM
// Opaque handle for the batched sparse-QR API (cusolverSp); SCALE omits it.
struct csrqrInfo;
typedef struct csrqrInfo* csrqrInfo_t;
typedef enum {
  CUSOLVER_EIG_RANGE_ALL = 1001,
  CUSOLVER_EIG_RANGE_I   = 1002,
  CUSOLVER_EIG_RANGE_V   = 1003,
} cusolverEigRange_t;

// SCALE lacks the selective symmetric eigensolver (syevdx). cusolverGetProperty
// below reports a version < 11.6.3, which steers raft to the classic syevd/syevj
// paths (which SCALE provides). These stubs exist only so any residual
// (never-taken) syevdx references still link; they are not expected to run.
static inline cusolverStatus_t cusolverDnSsyevdx_bufferSize(
  cusolverDnHandle_t, cusolverEigMode_t, cusolverEigRange_t,
  cublasFillMode_t, int, const float*, int,
  float, float, int, int, int*, const float*, int* lwork)
{ if (lwork) *lwork = 0; return CUSOLVER_STATUS_NOT_SUPPORTED; }
static inline cusolverStatus_t cusolverDnDsyevdx_bufferSize(
  cusolverDnHandle_t, cusolverEigMode_t, cusolverEigRange_t,
  cublasFillMode_t, int, const double*, int,
  double, double, int, int, int*, const double*, int* lwork)
{ if (lwork) *lwork = 0; return CUSOLVER_STATUS_NOT_SUPPORTED; }
static inline cusolverStatus_t cusolverDnSsyevdx(
  cusolverDnHandle_t, cusolverEigMode_t, cusolverEigRange_t,
  cublasFillMode_t, int, float*, int,
  float, float, int, int, int*, float*, float*, int, int*)
{ return CUSOLVER_STATUS_NOT_SUPPORTED; }
static inline cusolverStatus_t cusolverDnDsyevdx(
  cusolverDnHandle_t, cusolverEigMode_t, cusolverEigRange_t,
  cublasFillMode_t, int, double*, int,
  double, double, int, int, int*, double*, double*, int, int*)
{ return CUSOLVER_STATUS_NOT_SUPPORTED; }

// SCALE omits cusolverGetProperty; raft uses it to version-gate eig paths.
// Report 11.5.0 (< 110603) to select the classic syevd/syevj code paths.
static inline cusolverStatus_t cusolverGetProperty(libraryPropertyType type, int* value)
{
  if (value) {
    switch (type) {
      case MAJOR_VERSION: *value = 11; break;
      case MINOR_VERSION: *value = 5;  break;
      case PATCH_LEVEL:   *value = 0;  break;
      default:            *value = 0;  break;
    }
  }
  return CUSOLVER_STATUS_SUCCESS;
}
#endif
