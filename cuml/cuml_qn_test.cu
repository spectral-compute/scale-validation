#include <cuml/linear_model/glm.hpp>
#include <cuml/linear_model/qn.h>
#include <raft/core/handle.hpp>
#include <cuda_runtime.h>
#include <cstdio>
#include <vector>
#include <cmath>

int main() {
  // y = 2*x0 + 3*x1 + 1 ; 4 rows, 2 cols, column-major
  const int N = 4, D = 2, C = 1;
  std::vector<float> h_X = {1,1,2,3,  1,2,2,1};
  std::vector<float> h_y = {6,9,11,10};
  float *d_X=nullptr,*d_y=nullptr,*d_w=nullptr;
  cudaMalloc(&d_X, sizeof(float)*N*D);
  cudaMalloc(&d_y, sizeof(float)*N);
  cudaMalloc(&d_w, sizeof(float)*(D+1)*C);
  cudaMemcpy(d_X, h_X.data(), sizeof(float)*N*D, cudaMemcpyHostToDevice);
  cudaMemcpy(d_y, h_y.data(), sizeof(float)*N, cudaMemcpyHostToDevice);
  cudaMemset(d_w, 0, sizeof(float)*(D+1)*C);

  ML::GLM::qn_params params;
  params.loss = ML::GLM::QN_LOSS_SQUARED;
  params.penalty_l1 = 0; params.penalty_l2 = 0;
  params.grad_tol = 1e-8; params.change_tol = 1e-9;
  params.max_iter = 1000; params.fit_intercept = true;

  raft::handle_t handle;
  float f = 0; int iters = 0;
  ML::GLM::qnFit<float,int>(handle, params, d_X, /*col_major=*/true, d_y,
                            N, D, C, d_w, &f, &iters);
  handle.sync_stream();

  std::vector<float> w((D+1)*C, 0.f);
  cudaMemcpy(w.data(), d_w, sizeof(float)*(D+1)*C, cudaMemcpyDeviceToHost);
  cudaDeviceSynchronize();

  printf("qnFit: iters=%d  final_loss=%.3e\n", iters, f);
  printf("weights = [%.4f, %.4f]  intercept = %.4f  (expected ~[2,3], 1)\n", w[0], w[1], w[2]);
  bool ok = std::fabs(w[0]-2)<0.15 && std::fabs(w[1]-3)<0.15 && std::fabs(w[2]-1)<0.2;
  printf("%s\n", ok ? "QN RESULT CORRECT - cuML executed on the MI210 via SCALE" : "RESULT OFF");
  cudaFree(d_X); cudaFree(d_y); cudaFree(d_w);
  return ok ? 0 : 1;
}
