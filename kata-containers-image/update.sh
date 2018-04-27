#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# Automation script to create specs to build kata-containers-image
# Default image to build is the one specified in file versions.txt
# located at the root of the repository.
set -e

source ../versions.txt
source ../scripts/pkglib.sh

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname $0)
PKG_NAME="kata-containers-image"
VERSION=$kata_osbuilder_version
RELEASE=$(cat release)

BUILD_DISTROS=${BUILD_DISTROS:-Fedora_27 xUbuntu_16.04 CentOS_7)
GENERATED_FILES=(kata-containers-image.spec kata-containers-image.dsc debian.rules)
STATIC_FILES=(LICENSE debian.control debian.compat debian.changelog debian.dirs osbuilder/kata-containers.tar.gz)

COMMIT=false
BRANCH=false
LOCAL_BUILD=false
OBS_PUSH=false
VERBOSE=false

# Parse arguments
cli "$@"

[ "$VERBOSE" == "true" ] && set -x || true
PROJECT_REPO=${PROJECT_REPO:-home:katacontainers:release/kata-containers-image}
[ -n "$APIURL" ] && APIURL="-A ${APIURL}" || true

function check_image() {
    [ ! -f "${SCRIPT_DIR}/osbuilder/kata-containers.tar.gz" ] && die "No kata-containers.tar.gz found!\nUse the build_image.sh script" || echo "Image: OK"
}

# Generate specs using templates
function template()
{
    sed -i s/"kata_vm_image_version=${kata_vm_image_version}"/"kata_vm_image_version=${VERSION}"/ ${SCRIPT_DIR}/../versions.txt

    sed -e "s/\@VERSION\@/$VERSION/g" \
        -e "s/\@RELEASE\@/$RELEASE/g" \
        -e "s/@AGENT_SHA@/${kata_agent_hash:0:7}/" \
        -e "s/@ROOTFS_OS@/$osbuilder_default_os/" \
        kata-containers-image.spec-template > kata-containers-image.spec

    sed -e "s/\@VERSION\@/$VERSION/g" \
        -e "s/\@RELEASE\@/$RELEASE/g" \
        kata-containers-image.dsc-template > kata-containers-image.dsc

    sed -e "s/\@VERSION\@/$VERSION/g" \
        -e "s/@AGENT_SHA@/${kata_agent_hash:0:7}/" \
        -e "s/@ROOTFS_OS@/$osbuilder_default_os/" \
        debian.rules-template > debian.rules

}

verify
check_image
echo "Verify succeed."
get_git_info
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
	obs_push $PKG_NAME
fi
echo "OBS working copy directory: ${OBS_WORKDIR}"
