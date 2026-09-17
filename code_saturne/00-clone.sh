#!/bin/bash
#
# Clone code_saturne at the version pinned in versions.txt, plus the mesh
# format libraries it is built against.
#
# Most of the tutorials ship their meshes as MED files and a few as CGNS. The
# preprocessor rejects both formats outright unless code_saturne was configured
# with those libraries, which leaves only 04_Three_2D_Disks (native .des) and
# 13_Fluid_Structure_Interaction (gmsh) runnable -- so 02-build-deps.sh builds
# them and 03-build.sh configures against them.
#
# Their versions are inlined below rather than pinned in versions.txt: that
# file tracks the projects under test, and these are dependencies of one. They
# are the versions code_saturne 9.2's own installer pins (see the package list
# in install_saturne.py), which matters because the three are coupled -- MED 5
# wants HDF5 1.12, and code_saturne checks the MED version it links against.

set -ETeuo pipefail

# shellcheck source=../util/git.sh
source "$(dirname "$0")"/../util/git.sh

do_clone_hash code_saturne https://github.com/code-saturne/code_saturne.git "$(get_version code_saturne)"

do_clone_hash saturne_tutorials https://github.com/code-saturne/saturne-tutorials main

do_clone hdf5 https://github.com/HDFGroup/hdf5.git hdf5-1_12_3

do_clone cgns https://github.com/CGNS/CGNS.git v4.4.0

# MED (med-fichier) has no upstream git repository -- the salome-platform
# tarball is the only distribution. github.com/SalomePlatform/med is a
# different thing: the SALOME MED module, not the file library.
MED_VERSION=5.0.0
MED_ARCHIVE="med-${MED_VERSION}.tar.bz2"

# files.salome-platform.org sits behind a filter that 403s wget's default
# user agent, hence -U.
wget -U "Mozilla/5.0" "https://files.salome-platform.org/Salome/medfile/${MED_ARCHIVE}"
tar -xf "${MED_ARCHIVE}"

# Use a directory without a version in its name, matching the clones above.
rm -rf med
mv "med-${MED_VERSION}" med
