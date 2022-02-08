#!/bin/bash -eu

CLEAN=NO
if [ $# == 1 ] && [ "$1" == "--clean" ]; then
    CLEAN=YES
fi

DIR=$(cd $(dirname $0) && pwd)
export SPACK_USER_CACHE_PATH="${DIR}/spack_user_cache"

export TMP="${DIR}/tmp"
export TMPDIR="${TMP}"
mkdir -p tmp

echo "
##
## 1. Cleanup (optional)
##"
if [ "$CLEAN" == "YES" ]; then
    # Cleanup Spack User Cache
    rm -rf ~/.spack
    # Cleanup Spack
    if [ -d "${DIR}/git/spack/" ]; then
        (cd "${DIR}/git/spack/" && git clean -xdff && git checkout .)
    fi
    # Cleanup mirror
    rm -rf "${DIR}/spack_mirror"
    rm -rf "${SPACK_USER_CACHE_PATH}"
fi
if [ ! -d "${DIR}/git/spack/" ]; then
    mkdir -p "${DIR}/git/"
    (cd "${DIR}/git/" && git clone -c feature.manyFiles=true https://github.com/spack/spack.git)
fi

echo "
##
## 2. Load & Init Spack
##"
source "${DIR}/git/spack/share/spack/setup-env.sh"
spack compiler find
# /!\ Disable github action to force clingo to be built from sources
# This makes the bootstrap longer, but the mirror needs it to be sound
spack bootstrap untrust github-actions

echo "
##
## 3. Populate mirror with basics
##"
# Init mirror with clingo and its dependencies
spack mirror create -d "${DIR}/spack_mirror" --dependencies clingo-bootstrap
# still init bootstrap source cache ...
spack spec zlib

echo "
##
## 4. Complete Spack install
## => extra repos, patches, fetch extra depenencies, etc.
##"

## 4.2. Init env & concretize
spack env activate -d "${DIR}/"
spack concretize -f

## 4.3. Populate env mirror
spack mirror create -a -d "${DIR}/spack_mirror" --dependencies
rm -rf "${DIR}/spack.lock" "${DIR}/.spack-env"
