#!/bin/bash
#
# Copyright (c) 2017-2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

set -o errexit
set -o nounset
set -o pipefail

cidir=$(dirname "$0")
source "${cidir}/../scripts/lib.sh"
source /etc/os-release

if [ "$SNAP_CI" == "true" ] && [ "$ID" == "ubuntu" ]; then
### DEBUG
	echo "####### DEBUG:"
	pwd
	ls
##
	sudo multipass exec snapcraft -- snapcraft -d snap --destructive-mode
	exit $?
fi

pushd "${tests_repo_dir}"
.ci/run.sh
popd

# This script will execute packaging tests suite
