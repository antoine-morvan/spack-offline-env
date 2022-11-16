#!/usr/bin/env bash
set -eu

echo "ERROR: todo"
exit 1

DIR=${DIR:-$(dirname $(readlink -f $0))}

CLEAN=NO
SPACK_ENV_DIR=${DIR}/simple_env

##
## Read arguments
##
while [[ $# -gt 0 ]]; do
    case $1 in
    -c|--clean)
        CLEAN=YES
        shift # past argument
        ;;
    -e|--env)
        SPACK_ENV_DIR=$2
        shift # past argument
        shift # past value
        ;;
    *)
        echo "ERROR: Unknown option $1"
        exit 1
        ;;
    esac
done

SPACK_ROOT="${DIR}/git/spack/"
SPACK_BOOTSTRAP_ROOT="${DIR}/spack_bootstrap"
SPACK_USER_CACHE_PATH="${DIR}/spack_user_cache"
SPACK_MIRROR_PATH="${DIR}/spack_mirror"
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
spack config add config:source_cache:"${SPACK_MIRROR_PATH}"
spack compiler find

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