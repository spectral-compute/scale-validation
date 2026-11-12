#!/usr/bin/env bash
#
# Everything 00-clone.sh fetches, plus the mesh for the UEABS lid-driven cavity
# (see ueabs_cavity/setup.xml): 13M tetrahedra, already in the solver's own
# format, so it needs no preprocessing. The tarball also carries the case's
# code_saturne 7.0 Fortran user files, which setup.xml replaces.
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

bash "${SCRIPT_DIR}/../00-clone.sh"

ueabs=CS_7.0.0_PRACE_UEABS_CAVITY_13M
wget "https://repository.prace-ri.eu/ueabs/Code_Saturne/2.2/${ueabs}.tar.gz"
mkdir -p ueabs
tar -xzf "${ueabs}.tar.gz" -C ueabs --strip-components=1 "${ueabs}/mesh_input.csm"
rm "${ueabs}.tar.gz"
