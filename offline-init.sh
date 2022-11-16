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


SPACK_GIT_ROOT="${SPACK_ENV_DIR}/spack_git_root/"
SPACK_BOOTSTRAP_ROOT="${SPACK_ENV_DIR}/spack_bootstrap_root"
SPACK_USER_CACHE_PATH="${SPACK_ENV_DIR}/spack_user_cache"
SPACK_MIRROR_PATH="${SPACK_ENV_DIR}/spack_mirror"
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
source "${SPACK_GIT_ROOT}/share/spack/setup-env.sh"

function configureEnv() {
    # /!\ Disable github action to force clingo to be built from sources
    # This makes the bootstrap longer, but the mirror needs it to be sound
    spack bootstrap disable github-actions-v0.4
    spack bootstrap disable github-actions-v0.3
    spack bootstrap root "${SPACK_BOOTSTRAP_ROOT}"
    spack config add config:source_cache:"${SPACK_MIRROR_PATH}"
}
configureEnv

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

## Backup env file (before all variables get replaced by following steps)
cp ${SPACK_ENV_DIR}/spack.yaml ${SPACK_ENV_DIR}/spack.yaml.bk

## 4.2. Init env & concretize
spack env activate -d "${SPACK_ENV_DIR}/"

# reconfigure activated environment
configureEnv

spack concretize -f

## 4.3. Populate env mirror
spack mirror create -a -d "${SPACK_MIRROR_PATH}" --dependencies

## restore env file
mv ${SPACK_ENV_DIR}/spack.yaml.bk ${SPACK_ENV_DIR}/spack.yaml

## Cleanup
rm -rf "${SPACK_ENV_DIR}/spack.lock" "${SPACK_ENV_DIR}/.spack-env"
rm -rf "${TMP}"
