#!/bin/bash -eu

CLEAN=NO
if [ $# == 1 ] && [ "$1" == "--clean" ]; then
    CLEAN=YES
fi

DIR=$(cd $(dirname $0) && pwd)
export SPACK_USER_CACHE_PATH="${DIR}/spack_user_cache"
MIRROR_NAME=offline_spack_mirror

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
fi

echo "
##
## 2. Load & Init Spack
##"
source "${DIR}/git/spack/share/spack/setup-env.sh"
spack compiler find
spack bootstrap untrust github-actions

echo "
##
## 3. Init offline mirror
##"
set +e
RES=$(spack mirror list | grep "${MIRROR_NAME}" | wc -l)
set -e
if [ $RES == 0 ]; then
    spack mirror add "${MIRROR_NAME}" "file://${DIR}/spack_mirror"
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