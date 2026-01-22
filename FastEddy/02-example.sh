#!/bin/bash

set -e
set -u

OUT_DIR=$(realpath ../)
export PATH="${OUT_DIR}/openmpi/install/bin:${CUDA_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${OUT_DIR}/openmpi/install/lib:${LD_LIBRARY_PATH}"
export OMPI_MCA_accelerator=cuda

# Note: There are other examples in that directory. If you edit the file, lines
# right at the top allow you to use an `np` other than 4.

# Create a directory for the example.
EXAMPLES="${OUT_DIR}/FastEddy/examples"
EXAMPLE=Example01_NBL

rm -rf "${EXAMPLES}/${EXAMPLE}"
mkdir -p "${EXAMPLES}/${EXAMPLE}/output"

cd "${EXAMPLES}/${EXAMPLE}"
cp "${OUT_DIR}/FastEddy/FastEddy/tutorials/examples/Example01_NBL.in" .

# Choose how many processes to require.
if [ -z "$(which scalediag)" ] || scalediag full-driver p2p ; then
    NP=4
else
    NP=1
fi
echo "Using ${NP} processes"
sed -E "s/^numProcsX = 4 /numProcsX = ${NP} /" -i Example01_NBL.in

# Shrink the example to a size that can run on an RTX 3080 TI.
WIDTH=320
HEIGHT=318
sed -E "s/^Nx = 640 /Nx = ${WIDTH} /;s/^Ny = 634 /Ny = ${HEIGHT} /" -i Example01_NBL.in

# Make the test run in a tractable amount of time.
BATCH=300
TIME=6300
sed -E "s/^frqOutput = 7500 /frqOutput = ${BATCH} /;s/^NtBatch = 7500 /NtBatch = ${BATCH} /" -i Example01_NBL.in
sed -E "s/^Nt = 630000 /Nt = ${TIME} /" -i Example01_NBL.in

# Run FastEddy.
/usr/bin/time -f 'Time: %e' mpirun -np ${NP} "${OUT_DIR}/FastEddy/FastEddy/SRC/FEMAIN/FastEddy" Example01_NBL.in

# Generate the graphs.
cd "${EXAMPLES}"
cp "${OUT_DIR}/FastEddy/FastEddy/tutorials/notebooks"/{MAKE_FE_TUTORIAL_PLOTS.ipynb,feplot.mplstyle,fetutorialfunctions.py} .

sed -E "s|INSERT_PATH_TO_YOUR_RUN_DIRECTORY\\\\\\\\|${EXAMPLES}/|" -i MAKE_FE_TUTORIAL_PLOTS.ipynb
sed -E 's/save_plot_opt = 0/save_plot_opt = 1/' -i MAKE_FE_TUTORIAL_PLOTS.ipynb
sed -E "s/case = 'convective'/case = 'neutral'/" -i MAKE_FE_TUTORIAL_PLOTS.ipynb
sed -E "s/FE_timestep = \['630000']/FE_timestep = ['${TIME}']/" -i MAKE_FE_TUTORIAL_PLOTS.ipynb
sed -E "s/FE_timestep_avg = \['540000','555000','570000','585000','600000','615000','630000']/FE_timestep_avg = [str(${TIME} - ${BATCH} * i) for i in range(6, -1, -1)]/" \
    -i MAKE_FE_TUTORIAL_PLOTS.ipynb

jupyter execute MAKE_FE_TUTORIAL_PLOTS.ipynb

# Compare these graphs against a reference.
function cmp
{
    NAME=$1
    LIMIT=$2
    CMP="$(compare -metric mse "${SCRIPT_DIR}/ref-${NP}/${NAME}" \
                               "${EXAMPLE}/FIGS/${NAME}" /dev/null 2>&1 | cut -f 1 -d ' ')"
    echo "MSE ${NAME}: ${CMP} (maximum ${LIMIT})"
    if [ "$(echo "print(${CMP} < ${LIMIT})" | python3)" != "True" ] ; then
        echo "TOO DIFFERENT"
        exit 1
    fi
}
cmp MEAN-PROF-neutral.png 0.08
cmp TURB-PROF-neutral.png 0.064
cmp UVWTHETA-XY-neutral.png 160
cmp UVWTHETA-XZ-neutral.png 20
