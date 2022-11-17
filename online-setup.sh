#!/usr/bin/env bash
set -eu

SCRIPT_DIR=${SCRIPT_DIR:-$(dirname $(readlink -f $0))}
TMPDIR=${TMPDIR:-"${SCRIPT_DIR}/.tmp"}

CLEAN=NO
SPACK_ENV_DIR=${SCRIPT_DIR}/simple_env

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

SPACK_GIT_ROOT="${SPACK_ENV_DIR}/spack_git_root/"
SPACK_BOOTSTRAP_ROOT="${SPACK_ENV_DIR}/spack_bootstrap_root"
SPACK_USER_CACHE_PATH="${SPACK_ENV_DIR}/spack_user_cache"
SPACK_MIRROR_PATH="${SPACK_ENV_DIR}/spack_mirror"
MIRROR_NAME=offline_spack_mirror

TMP="${TMPDIR}"

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
if [ ! -d "${SPACK_GIT_ROOT}" ]; then
    mkdir -p "$(dirname ${SPACK_GIT_ROOT})"
    git clone -c feature.manyFiles=true https://github.com/spack/spack.git "${SPACK_GIT_ROOT}"
fi
rm -rf "${TMP}"
mkdir -p "${TMP}"

echo "
##
## 2. Load & Init Spack
##"
source "${SPACK_GIT_ROOT}/share/spack/setup-env.sh"

function configureEnv() {
    spack bootstrap root "${SPACK_BOOTSTRAP_ROOT}"
    spack config add config:source_cache:"${SPACK_MIRROR_PATH}"
}
configureEnv

echo "
##
## 3. Bootstrap Clingo
##"
spack spec zlib

echo "
##
## 4. Concretize and Install offline env
##"
spack env activate -d "${SPACK_ENV_DIR}/"
spack concretize -f
spack install -v -j $(nproc) --fail-fast