#!/bin/bash
#
# Copyright (c) 2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

set -o errexit
set -o nounset
set -o pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_name="$(basename "${BASH_SOURCE[0]}")"

readonly tmp_dir=$(mktemp -t -d pr-bump.XXXX)
readonly organization="kata-containers"
readonly dockerfile_path="kata-deploy/Dockerfile"
readonly repo="packaging"

PUSH="false"
GOPATH=${GOPATH:-${HOME}/go}

source "${script_dir}/../scripts/lib.sh"

cleanup() {
	[ -d "${tmp_dir}" ] && rm -rf "${tmp_dir}"
}

trap cleanup EXIT

bump_kata_deploy() {
	local new_version="${1:-}"
	local target_branch="${2:-}"
	[ -n "${new_version}" ] || die "no new version"
	[ -n "${target_branch}" ] || die "no target branch"

	local remote_github="https://github.com/${organization}/${repo}.git"

	info "remote: ${remote_github}"

	git clone --quiet "${remote_github}"

	pushd "${repo}" >>/dev/null

	branch="${new_version}-kata-deploy-bump"
	git fetch origin "${target_branch}"
	git checkout "origin/${target_branch}" -b "${branch}"

	info "Updating kata-deploy Dockerfile"

	sed -i "s/KATA_VER=.*$/${new_version}/g" ${dockerfile_path}

	info "Creating PR message"
	notes_file=notes.md
	cat <<EOT >"${notes_file}"
bump kata-deploy to ${new_version}
EOT
	cat "${notes_file}"

	git add -u
	info "Creating commit with new changes"
	commit_msg="kata-deploy: bump to ${new_version}"
	git commit -s -m "${commit_msg}"

	if [[ ${PUSH} == "true" ]]; then
		build_hub
		info "Forking remote"
		${hub_bin} fork --remote-name=fork
		info "Push to fork"
		${hub_bin} push fork -f "${branch}"
		info "Create PR"
		out=""
		out=$("${hub_bin}" pull-request -b "${target_branch}" -F "${notes_file}" 2>&1) || echo "$out" | grep "A pull request already exists"
	fi
	popd >>/dev/null
}

usage() {
	exit_code="$1"
	cat <<EOT
Usage:
	${script_name} [options] <args>
Args:
	<new-version>     : New version to bump kata-deploy to
	<target-branch>   : The base branch to create PR for
Example:
	${script_name} 1.10 master
Options
	-h        : Show this help
	-p        : create a PR
EOT
	exit "$exit_code"
}

while getopts "hp" opt; do
	case $opt in
	h) usage 0 ;;
	p) PUSH="true" ;;
	esac
done

shift $((OPTIND - 1))

new_version=${1:-}
target_branch=${2:-}
[ -n "${new_version}" ] || (echo "ERROR: no new version" && usage 1)
[ -n "${target_branch}" ] || die "no target branch"

pushd "$tmp_dir" >>/dev/null
bump_kata_deploy "${new_version}" "${target_branch}"
popd >>/dev/null
