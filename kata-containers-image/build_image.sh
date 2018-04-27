#!/bin/bash
set -x

source ../versions.txt

SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname $0)

OSBUILDER_URL=https://github.com/kata-containers/osbuilder.git
OSBUILDER_DIR="${SCRIPT_DIR}/osbuilder"

DISTRO="$osbuilder_default_os"
OS_VERSION="$clearlinux_version"
CLR_BASE_URL="https://download.clearlinux.org/releases/${clearlinux_version}/clear/x86_64/os/"

AGENT_SHA="$kata_agent_hash"

if [ ! -e "$OSBUILDER_DIR" ]; then
    git clone $OSBUILDER_URL
fi

pushd $OSBUILDER_DIR
git checkout $kata_osbuilder_version
sudo -E PATH=$PATH make image \
     DISTRO=$DISTRO \
     AGENT_VERSION=$AGENT_SHA \
     OS_VERSION=$OS_VERSION \
     BASE_URL=$CLR_BASE_URL

mv kata-containers.img kata-containers-image_${DISTRO}_agent_${AGENT_SHA:0:7}.img
sudo tar cfz "kata-containers.tar.gz" "kata-containers-image_${DISTRO}_agent_${AGENT_SHA:0:7}.img"
popd
