#!/bin/bash -eu

CLEAN=NO
if [ $# == 1 ] && [ "$1" == "--clean" ]; then
    CLEAN=YES
fi

DIR=$(cd $(dirname $0) && pwd)

SPACK_ROOT="${DIR}/git/spack/"
SPACK_MIRROR_PATH="${DIR}/spack_mirror"
MIRROR_NAME=offline_spack_mirror
SPACK_BOOTSTRAP_ROOT="${DIR}/spack_bootstrap"
SPACK_USER_CACHE_PATH="${DIR}/spack_user_cache"
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
fi
rm -rf "${TMP}"
mkdir -p "${TMP}"

echo "
##
## 2. Load & Init Spack
##"
source "${DIR}/git/spack/share/spack/setup-env.sh"
spack compiler find
spack bootstrap untrust github-actions
spack bootstrap root "${SPACK_BOOTSTRAP_ROOT}"

echo "
##
## 3. Init offline mirror
##"
set +e
RES=$(spack mirror list | grep "${MIRROR_NAME}" | wc -l)
set -e
if [ $RES == 0 ]; then
    spack mirror add "${MIRROR_NAME}" "file://${SPACK_MIRROR_PATH}"
fi

echo "
##
## 4. Bootstrap Clingo
##"
spack -d spec zlib

echo "
##
## 5. Init offline env
##"
spack env activate -d "${DIR}/"
spack concretize -f
spack install -v -j $(nproc) --fail-fast