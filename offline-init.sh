#!/usr/bin/env bash
set -eu

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


SPACK_GIT_ROOT="${DIR}/git/spack/"
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
    rm -rf "${SPACK_USER_CACHE_PATH}" "${SPACK_BOOTSTRAP_ROOT}" "${SPACK_MIRROR_PATH}"
    # Cleanup Spack
    if [ -d "${SPACK_GIT_ROOT}" ]; then
        (cd "${SPACK_GIT_ROOT}" && git clean -xdff && git checkout .)
    fi
    # Cleanup mirror
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
source "${DIR}/git/spack/share/spack/setup-env.sh"

# /!\ Disable github action to force clingo to be built from sources
# This makes the bootstrap longer, but the mirror needs it to be sound
spack compiler find --scope site
spack bootstrap disable github-actions-v0.4
spack bootstrap disable github-actions-v0.3
spack bootstrap root "${SPACK_BOOTSTRAP_ROOT}"
spack config add config:source_cache:"${SPACK_MIRROR_PATH}"

echo "
##
## 3. Populate mirror with basics
##"
# bootstrap clingo
spack spec zlib
# Init mirror with spack basic dependencies
spack mirror create -d "${SPACK_MIRROR_PATH}" --dependencies clingo-bootstrap gnuconfig

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
