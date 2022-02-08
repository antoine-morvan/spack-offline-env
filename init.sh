#!/bin/bash -eu

CLEAN=NO
if [ $# == 1 ] && [ "$1" == "--clean" ]; then
    CLEAN=YES
fi

DIR=$(cd $(dirname $0) && pwd)

SPACK_ROOT="${DIR}/git/spack/"
SPACK_BOOTSTRAP_ROOT="${DIR}/spack_bootstrap"
SPACK_USER_CACHE_PATH="${DIR}/spack_user_cache"
SPACK_MIRROR_PATH="${DIR}/spack_mirror"
SPACK_SOURCE_CACHE_PATH="${SPACK_MIRROR_PATH}"
MIRROR_NAME=offline_spack_mirror
TMP="${DIR}/.tmp"
TMPDIR="${TMP}"

export SPACK_USER_CACHE_PATH
export TMP
export TMPDIR

echo "
##
## 1. Cleanup (optional)
##"
if [ "$CLEAN" == "YES" ]; then
    # Cleanup Spack User Cache
    rm -rf "${SPACK_USER_CACHE_PATH}" "${SPACK_BOOTSTRAP_ROOT}"
    # Cleanup Spack
    if [ -d "${SPACK_ROOT}" ]; then
        (cd "${SPACK_ROOT}" && git clean -xdff && git checkout .)
    fi
    # Cleanup mirror
    rm -rf "${SPACK_MIRROR_PATH}"
    rm -rf "${SPACK_USER_CACHE_PATH}"
fi
if [ ! -d "${SPACK_ROOT}" ]; then
    mkdir -p "$(dirname ${SPACK_ROOT})"
    git clone -c feature.manyFiles=true https://github.com/spack/spack.git "${SPACK_ROOT}"
fi
rm -rf "${TMP}"
mkdir -p "${TMP}"

echo "
##
## 2. Load & Init Spack
##"
source "${DIR}/git/spack/share/spack/setup-env.sh"
# /!\ Disable github action to force clingo to be built from sources
# This makes the bootstrap longer, but the mirror needs it to be sound
spack bootstrap untrust github-actions
spack bootstrap root "${SPACK_BOOTSTRAP_ROOT}"
spack config add config:source_cache:"${SPACK_SOURCE_CACHE_PATH}"
spack compiler find

echo "
##
## 3. Populate mirror with basics
##"
# bootstrap clingo
spack spec zlib
# Init mirror with clingo and its dependencies
spack mirror create -d "${SPACK_MIRROR_PATH}" --dependencies clingo-bootstrap

echo "
##
## 4. Complete Spack install
## => extra repos, patches, fetch extra depenencies, etc.
##"

## 4.2. Init env & concretize
spack env activate -d "${DIR}/"
spack concretize -f

## 4.3. Populate env mirror
spack mirror create -a -d "${SPACK_MIRROR_PATH}" --dependencies

## Cleanup
rm -rf "${DIR}/spack.lock" "${DIR}/.spack-env"
rm -rf "${TMP}"
