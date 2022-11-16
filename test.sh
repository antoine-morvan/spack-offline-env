#!/bin/bash

N_INSTALL_PROCESS=8
NPROC=$(nproc)
NPROC_PER_PROCESS=$((NPROC / N_INSTALL_PROCESS))

source ${SPACK_GIT_ROOT}/share/spack/setup-env.sh

spack env activate -p -d ./env_folder
spack concretize -f

echo " -------------- "

spack install --no-checksum -v -j $NPROC

echo " -------------- "
spack find
