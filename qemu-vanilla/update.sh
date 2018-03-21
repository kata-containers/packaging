#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# Automation script to create specs to build clear containers kernel
set -e

source ../versions.txt
source ../scripts/pkglib.sh

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname $0)
PKG_NAME="qemu-vanilla"
VERSION=$qemu_vanilla_version
RELEASE=$(cat release)

BUILD_DISTROS=${BUILD_DISTROS:-Fedora_27 xUbuntu_16.04 CentOS_7)
GENERATED_FILES=(qemu-vanilla.dsc qemu-vanilla.spec debian.rules )
STATIC_FILES=(debian.compat debian.control _service *.patch ../scripts/configure-hypervisor.sh qemu-vanilla-rpmlintrc)

COMMIT=false
BRANCH=false
LOCAL_BUILD=false
OBS_PUSH=false
VERBOSE=false

# Parse arguments
cli "$@"

[ "$VERBOSE" == "true" ] && set -x || true
PROJECT_REPO=${PROJECT_REPO:-home:katacontainers:release/qemu-vanilla}
[ -n "$APIURL" ] && APIURL="-A ${APIURL}" || true

# Generate specs using templates
function template(){
    sed "s/@VERSION@/${VERSION}/g" _service-template > _service
    sed "s/\@VERSION\@/${VERSION}/g; s/\@RELEASE\@/${RELEASE}/g; s/\@QEMU_VANILLA_HASH\@/${qemu_vanilla_hash:0:10}/g" qemu-vanilla.spec-template > qemu-vanilla.spec
    sed "s/\@VERSION\@/${VERSION}/g; s/\@RELEASE\@/${RELEASE}/g; s/\@QEMU_VANILLA_HASH\@/${qemu_vanilla_hash:0:10}/g" qemu-vanilla.dsc-template > qemu-vanilla.dsc
    sed "s/\@VERSION\@/${VERSION}/g; s/\@RELEASE\@/${RELEASE}/g; s/\@QEMU_VANILLA_HASH\@/${qemu_vanilla_hash:0:10}/g" debian.rules-template > debian.rules
}

verify
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
	obs_push "cc-runtime"
fi
echo "OBS working copy directory: ${OBS_WORKDIR}"
