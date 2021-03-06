#!/bin/bash
#
# Copyright (c) 2019 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
set -x

export GOPATH=~/go
export kata_repo="github.com/kata-containers/packaging"
export pr_number=${GITHUB_PR:-}
export pr_branch="PR_${pr_number}"

TEST_REPO_DIR="${GOPATH}/src/github.com/kata-containers/tests"
mkdir -p $(dirname "TEST_REPO_DIR")
git clone https://github.com/kata-containers/tests.git "${TEST_REPO_DIR}"
cd "${TEST_REPO_DIR}"
git checkout "${branch}"
.ci/resolve-kata-dependencies.sh
