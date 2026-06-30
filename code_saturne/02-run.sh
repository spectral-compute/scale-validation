#!/bin/bash
#
# Set up a 100x100x1 Cartesian channel case: inlet velocity at x=0, pressure
# outlet at x=1, no-slip walls elsewhere. Run 10 time steps and confirm that
# the GPU linear solver was dispatched and iterated, and the run completed.

set -ETeuo pipefail

cs_install_dir="$(realpath code_saturne-install)"
export PATH="${cs_install_dir}/bin:${PATH}"

# cs_sles_solve_ccc_fv allocates extended solver buffers as CS_ALLOC_DEVICE
# (device-only), then passes them to the CPU convergence check, causing SIGSEGV.
# This remaps cs_alloc_mode_device to CS_ALLOC_HOST_DEVICE_SHARED at init time.
# See cs_base_cuda.cu:777.
export CS_CUDA_ALLOC_DEVICE_UVM=1

rm -rf Validation
code_saturne create --study Validation --case channel

# Boundary zones must be non-overlapping; the walls criteria excludes inlet
# and outlet faces explicitly.
cat > Validation/channel/DATA/setup.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<Code_Saturne_GUI case="channel" solver_version="" study="Validation" version="2.0">
  <calculation_management/>
  <solution_domain>
    <mesh_origin choice="mesh_cartesian"/>
    <mesh_cartesian>
      <x_direction law="constant" ncells="100" min="0.0" max="1.0" prog="1.0"/>
      <y_direction law="constant" ncells="100" min="0.0" max="1.0" prog="1.0"/>
      <z_direction law="constant" ncells="1" min="0.0" max="0.01" prog="1.0"/>
    </mesh_cartesian>
  </solution_domain>
  <analysis_control>
    <time_parameters>
      <time_step_ref>0.01</time_step_ref>
      <iterations>10</iterations>
    </time_parameters>
  </analysis_control>
  <boundary_conditions>
    <boundary label="inlet" name="1" nature="inlet">x &lt; 0.001</boundary>
    <boundary label="outlet" name="2" nature="outlet">x &gt; 0.999</boundary>
    <boundary label="walls" name="3" nature="wall">not (x &lt; 0.001) and not (x &gt; 0.999)</boundary>
    <inlet label="inlet" field_id="none">
      <velocity_pressure choice="norm" direction="normal">
        <norm>1.0</norm>
      </velocity_pressure>
    </inlet>
  </boundary_conditions>
</Code_Saturne_GUI>
EOF

(cd Validation/channel && code_saturne run) 2>&1 | tee run.log

solver_log="$(find Validation/channel/RESU -name run_solver.log | sort | tail -1)"

if [ -z "${solver_log}" ]; then
  echo "Error: no run_solver.log found in RESU." >&2
  exit 1
fi

resu_dir="$(dirname "${solver_log}")"

if ! grep -q "CUDA device [0-9]" "${solver_log}"; then
  echo "Error: 'CUDA device <N>' not found in run_solver.log: GPU was not initialised." >&2
  exit 1
fi

if ! grep -q "device SpMV variant" "${resu_dir}/performance.log"; then
  echo "Error: 'device SpMV variant' not found in performance.log: GPU solver not dispatched." >&2
  exit 1
fi

if ! grep -q "END OF CALCULATION" "${solver_log}"; then
  echo "Error: 'END OF CALCULATION' not found in run_solver.log: run did not complete." >&2
  exit 1
fi

echo "GPU dispatch confirmed and calculation completed successfully."
