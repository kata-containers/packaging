#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Automation script to create specs to build ksm-throttler.
# Default: Build is the one specified in file configure.ac
# located at the root of the repository.
set -e

source ../versions.txt
source ../scripts/pkglib.sh

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname $0)
PKG_NAME="kata-ksm-throttler"
VERSION=$ksm_throttler_version
HASH=$ksm_throttler_hash
RELEASE=$(cat release)

BUILD_DISTROS=${BUILD_DISTROS:-Fedora_27 xUbuntu_16.04 CentOS_7)
GENERATED_FILES=(_service kata-ksm-throttler.spec kata-ksm-throttler.dsc debian.control debian.rules)
STATIC_FILES=(debian.compat)

COMMIT=false
BRANCH=false
LOCAL_BUILD=false
OBS_PUSH=false
VERBOSE=false

# Parse arguments
cli "$@"

[ "$VERBOSE" == "true" ] && set -x || true
PROJECT_REPO=${PROJECT_REPO:-home:katacontainers:release/ksm-throttler}
[ -n "$APIURL" ] && APIURL="-A ${APIURL}" || true

# Generate specs using templates
function template()
{
    sed -e "s/@VERSION@/$VERSION/g" \
        -e "s/@HASH@/${HASH:0:7}/g" \
        -e "s/@RELEASE@/$RELEASE/g" \
        -e "s/@GO_VERSION@/$go_version/g" \
	kata-ksm-throttler.spec-template > kata-ksm-throttler.spec

    sed -e "s/@VERSION@/$VERSION/g" \
        -e "s/@HASH@/${HASH:0:7}/g"\
        -e "s/@RELEASE@/$RELEASE/g" \
	kata-ksm-throttler.dsc-template > kata-ksm-throttler.dsc

    sed -e "s/@VERSION@/$VERSION/g" \
        -e "s/@HASH@/${HASH:0:7}/g"\
	debian.control-template > debian.control

    sed "s/@GO_VERSION@/$go_version/g" debian.rules-template > debian.rules

    # If OBS_REVISION is not empty, which means a branch or commit ID has been passed as argument,
    # replace it as @REVISION@ in the OBS _service file. Otherwise, use the VERSION variable,
    # which uses the version from versions.txt.
    # This will determine which source tarball will be retrieved from github.com
    if [ -n "$OBS_REVISION" ]; then
	sed -e "s/@REVISION@/$OBS_REVISION/" \
            -e "s/@VERSION@/$VERSION/g" \
            -e "s/@GO_VERSION@/$go_version/g" \
            -e "s/@GO_CHECKSUM@/$go_checksum/" \
            _service-template > _service
    else
	sed -e "s/@REVISION@/$HASH/"  \
            -e "s/@VERSION@/$VERSION/g" \
            -e "s/@GO_VERSION@/$go_version/g" \
            -e "s/@GO_CHECKSUM@/$go_checksum/" \
            _service-template > _service
    fi
}

verify
echo "Verify succeed."
get_git_info
set_versions $HASH
changelog_update $VERSION
template

if [ "$LOCAL_BUILD" == "true" ] && [ "$OBS_PUSH" == "true" ]
then
    die "--local-build and --push are mutually exclusive."
elif [ "$LOCAL_BUILD" == "true" ]
then
	checkout_repo $PROJECT_REPO
	local_build

elif [ "$OBS_PUSH" == "true" ]
then
	checkout_repo $PROJECT_REPO
	obs_push "cc-runtime"
fi
echo "OBS working copy directory: ${OBS_WORKDIR}"
