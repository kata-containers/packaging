#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Automation script to create specs to build cc-runtime
# Default: Build is the one specified in file configure.ac
# located at the root of the repository.
set -e

source ../versions.txt
source ../scripts/pkglib.sh

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname $0)
PKG_NAME="kata-runtime"
VERSION=$kata_runtime_version
RELEASE=$(cat release)
PROXY_RELEASE=$(cat ../proxy/release)
SHIM_RELEASE=$(cat ../shim/release)
QEMU_LITE_RELEASE=$(cat ../qemu-lite/release)
KERNEL_RELEASE=$(cat ../kernel/release)
KSM_THROTTLER_RELEASE=$(cat ../ksm-throttler/release)
KATA_CONTAINERS_IMAGE_RELEASE=$(cat ../kata-containers-image/release)
APPORT_HOOK="source_cc-runtime.py"

BUILD_DISTROS=${BUILD_DISTROS:-Fedora_27 xUbuntu_16.04 CentOS_7)

GENERATED_FILES=(kata-runtime.spec kata-runtime.dsc debian.control debian.rules _service)
STATIC_FILES=(debian.compat)

COMMIT=false
BRANCH=false
LOCAL_BUILD=false
OBS_PUSH=false
VERBOSE=false

# Parse arguments
cli "$@"

[ "$VERBOSE" == "true" ] && set -x || true
PROJECT_REPO=${PROJECT_REPO:-home:katacontainers:release/runtime}
[ -n "$APIURL" ] && APIURL="-A ${APIURL}" || true

# Generate specs using templates
function template()
{
    sed -e "s/@VERSION@/$VERSION/g" \
	    -e "s/@RELEASE@/$RELEASE/g" \
	    -e "s/@HASH@/$short_hashtag/g" \
            -e "s/@kata_proxy_version@/${kata_proxy_version}+git.${kata_proxy_hash:0:7}-$PROXY_RELEASE/" \
	    -e "s/@kata_shim_version@/${kata_shim_version}+git.${kata_shim_hash:0:7}-$SHIM_RELEASE/" \
	    -e "s/@kata_osbuilder_version@/${kata_osbuilder_version}-${KATA_CONTAINERS_IMAGE_RELEASE}/" \
	    -e "s/@qemu_lite_version@/${qemu_lite_version}+git.${qemu_lite_hash:0:7}-${QEMU_LITE_RELEASE}/" \
	    -e "s/@linux_container_version@/${linux_container_version}-${KERNEL_RELEASE}/" \
	    -e "s/@ksm_throttler_version@/${ksm_throttler_version}-${KSM_THROTTLER_RELEASE}/" \
	    -e "s/@GO_VERSION@/$go_version/" \
	    kata-runtime.spec-template > kata-runtime.spec

    sed -e "s/@VERSION@/$VERSION/" \
        -e "s/@HASH@/$short_hashtag/" \
        -e "s/@GO_VERSION@/$go_version/" \
        debian.rules-template > debian.rules

    sed -e "s/@VERSION@/$VERSION/g"\
	    -e "s/@RELEASE@/$RELEASE/g" \
	    -e "s/@HASH@/$short_hashtag/g" \
	    -e "s/@kata_proxy_version@/$kata_proxy_version/" \
	    -e "s/@kata_shim_version@/$kata_shim_version/" \
	    -e "s/@kata_containers_image_version@/$kata_containers_image_version/" \
	    -e "s/@qemu_lite_version@/$qemu_lite_version/" \
	    -e "s/@linux_container_version@/$linux_container_version/" \
	    -e "s/@qemu_lite_version@/$qemu_lite_version/" \
	    -e "s/@kata_ksm_throttler_version@/$ksm_throttler_version/" \
	    kata-runtime.dsc-template > kata-runtime.dsc

    sed -e "s/@VERSION@/$VERSION/" \
	    -e "s/@HASH_TAG@/$short_hashtag/" \
	    -e "s/@cc_proxy_version@/$proxy_obs_ubuntu_version/" \
	    -e "s/@cc_shim_version@/$shim_obs_ubuntu_version/" \
	    -e "s/@cc_image_version@/$image_obs_ubuntu_version/" \
	    -e "s/@qemu_lite_version@/$qemu_lite_obs_ubuntu_version/" \
	    -e "s/@linux_container_version@/$linux_container_obs_ubuntu_version/" \
	    -e "s/@qemu_lite_obs_ubuntu_version@/$qemu_lite_obs_ubuntu_version/"  \
	    -e "s/@cc_ksm_throttler_version@/$ksm_throttler_version/" \
	    debian.control-template > debian.control

   sed -e "s/@GO_VERSION@/$go_version/g" \
       -e "s/@GO_CHECKSUM@/$go_checksum/" \
       -e "s/@VERSION@/$VERSION/g" \
       -e "s/@REVISION@/$VERSION/g" \
       _service-template > _service

}

verify
echo "Verify succeed."
get_git_info
set_versions $kata_runtime_hash
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
