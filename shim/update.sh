#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Automation script to create specs to build cc-shim
set -e

source ../versions.txt
source ../scripts/pkglib.sh

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname $0)
PKG_NAME="kata-shim"
VERSION=$kata_shim_version
RELEASE=$(cat release)

BUILD_DISTROS=${BUILD_DISTROS:-Fedora_27 xUbuntu_16.04 CentOS_7)
COMMIT=false
BRANCH=false
LOCAL_BUILD=false
OBS_PUSH=false
VERBOSE=false

GENERATED_FILES=(kata-shim.spec kata-shim.dsc _service debian.control debian.rules)
STATIC_FILES=(debian.compat)

# Parse arguments
cli "$@"

[ "$VERBOSE" == "true" ] && set -x || true
PROJECT_REPO=${PROJECT_REPO:-home:katacontainers:release/shim}
[ -n "$APIURL" ] && APIURL="-A ${APIURL}" || true

function template()
{
    sed -e "s/@VERSION@/$VERSION/g" \
        -e "s/@RELEASE@/$RELEASE/g" \
        -e "s/@HASH@/$short_hashtag/g" \
        -e "s/@GO_VERSION@/$go_version/g" \
        kata-shim.spec-template > kata-shim.spec

    sed -e "s/@HASH@/$short_hashtag/" \
        -e "s/@GO_VERSION@/$go_version/g" \
        debian.rules-template > debian.rules

    sed -e "s/@VERSION@/$VERSION/g" \
        -e "s/@HASH@/$short_hashtag/g" \
        -e "s/@RELEASE@/$RELEASE/g" kata-shim.dsc-template > kata-shim.dsc

    sed -e "s/@VERSION@/$VERSION/g" \
        -e "s/@HASH@/$short_hashtag/g" debian.control-template > debian.control

    # If OBS_REVISION is not empty, which means a branch or commit ID has been passed as argument,
    # replace It as @REVISION@ it in the OBS _service file. Otherwise, use the VERSION variable,
    # which uses the version from versions.txt.
    # This will determine which source tarball will be retrieved from github.com
    if [ -n "$OBS_REVISION" ]; then
        sed "s/@REVISION@/$OBS_REVISION/" _service-template > _service
    else
        sed -e "s/@REVISION@/$VERSION/" \
            -e "s/@VERSION@/$VERSION/g" \
            -e "s/@GO_VERSION@/$go_version/g" \
            -e "s/@GO_CHECKSUM@/$go_checksum/" \
            _service-template > _service
    fi
}

verify
echo "Verify succeed."
get_git_info
set_versions $kata_shim_hash
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
	obs_push
fi
echo "OBS working copy directory: ${OBS_WORKDIR}"
