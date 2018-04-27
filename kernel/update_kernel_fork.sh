#!/bin/bash
# Copyright (c) 2018 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
script_name="${0##*/}"
script_dir=$(dirname $(realpath -s "$0"))
release_tool="${script_dir}/release-tool"

die() {
	echo >&2 -e "\e[1mERROR\e[0m: $*"
	exit 1
}

info() {
	echo -e "\e[1mINFO\e[0m: $*"
}


# Linux stable repository: From here will pull latest kernel
# We can not pull from clear containers fork because is not automatically mirrored.
linux_stable_repo=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git 
# Repository to push new clear containers kernel
project_kernel_repo="git@github.com:clearcontainers/linux.git"
#We dont want to download all commits from linux that is a lot.
fetch_depth=5000

source "${script_dir}/../versions.txt"
#clear_vm_kernel_version is defined in versions.txt
major_version=$(echo "${clear_vm_kernel_version}" | cut -d "." -f 1)
major_revision=$(echo "${clear_vm_kernel_version}" | cut -d "." -f 2)
minor_revision=$(echo "${clear_vm_kernel_version}" | cut -d "." -f 3)
release_file="${script_dir}/release"
# Incremental number to identify a kernel change (patch, version or config)
cc_patch_number=$(cat "${release_file}")
push=false

# Stable branches are named: linux-x.xx.y, example: linux-4.9.x
stable_branch="linux-${major_version}.${major_revision}.y"

function sync_cc_repo() {
	local repo_dir="$(mktemp -d cc-linux-XXXXX)"
	local cc_kernel_version="${major_version}.${major_revision}.${minor_revision}-${cc_patch_number}"
	local cc_kernel_branch="${cc_kernel_version}.container"
	local cc_kernel_tag="v${cc_kernel_version}.container"
	info "get kernel sources based in barnch ${stable_branch}"
	git clone "${linux_stable_repo}" --branch "${stable_branch}" \
		--single-branch --depth "${fetch_depth}" --origin linux-stable "${repo_dir}"
	pushd "${repo_dir}"

	info "Repository to syncronize ${project_kernel_repo}"
	git remote add clearcontainers "${project_kernel_repo}"

	latest_cc_release=$(git ls-remote --tags clearcontainers  \
		| grep -oP '\-\d+\.container'  \
		| grep -oP '\d+' \
		| sort -n | \
		tail -1 )
	info "Latest patch release ${latest_cc_release}"
	if (( "${cc_patch_number}" <= "${latest_cc_release}" )) ; then
		die "The release number in file ${release_file} is not greater than the last release "
	fi

	info "Creating new kernel based on ${clear_vm_kernel_version}"
	git checkout -b "${cc_kernel_branch}" "v${clear_vm_kernel_version}"
	patches_dir="${script_dir}/patches-${major_version}.${major_revision}.x"
	info "Applying kernel patches"
	find  "${patches_dir}" -type f -name '*.patch' -exec git am {} \;
	kernel_config="${script_dir}/kernel-config-${major_version}.${major_revision}.x"
	info "Adding Kata Containers kernel configuration"
	cp "${kernel_config}" "arch/x86/configs/clear_containers_defconfig"
	git add "arch/x86/configs/clear_containers_defconfig"
	git commit -s -m "config: Add Kata Containers Config"
	git tag -m "${cc_kernel_tag}" "${cc_kernel_tag}"
	make clear_containers_defconfig
	info "building kernel"
	make -j "$(nproc)"
	info "Creating kernel binaries tarball"
	dist_bin_name="${cc_kernel_tag}-binaries"
	mkdir -p "${dist_bin_name}"
	dist_vmlinux="vmlinux-${cc_kernel_version}.container"
	dist_vmlinuz="vmlinuz-${cc_kernel_version}.container"
	cp vmlinux "${dist_bin_name}/${dist_vmlinux}"
	cp arch/x86/boot/bzImage "${dist_bin_name}/${dist_vmlinuz}"
	sed \
		-e "s|@VMLINUZ@|${dist_vmlinux}|g" \
		-e "s|@VMLINUX@|${dist_vmlinuz}|g" \
		"${script_dir}/Makefile.dist.install" > "${dist_bin_name}/Makefile"

	tarball="${dist_bin_name}.tar.gz"
	tar -zvcf "${tarball}" "${dist_bin_name}"
	shasum="SHA512SUMS"
	sha512sum "${tarball}" > "${shasum}"

	if [ "${push}" = true ]; then
		info "push changes to clearcontainers"
		git push clearcontainers "${cc_kernel_tag}"
		info "creating release"
		${release_tool} release --asset "${tarball}" --asset "${shasum}" --force-version --version "${cc_kernel_tag}" "linux"
	fi
	popd
	rm -rf "${repo_dir}"
}

build_release_tool() {
	pushd "${script_dir}/../release-tools/"
	info "build release tool"
	go build -o  "${release_tool}"
	popd
}

usage() { 
cat << EOT
Usage: $0 [options]
Options:
-h            : show this help
-k <git-repo> : git repository to push new kernel
-p            : Push to git-repo default: ${push}
-t <token>    : Github token to create new release. ENV: \$GITHUB_TOKEN
EOT
}        
while getopts hk:pt: opt
do
	case $opt in
		h)
			usage
			exit
			;;
		k)
			project_kernel_repo="${OPTARG}"
			;;
		p)
			push=true
			;;
		t)
			GITHUB_TOKEN=${OPTARG}
			;;
	esac
done
if [ "${push}" = true ]; then
	[ -z "$GITHUB_TOKEN" ] && die "\$GITHUB_TOKEN is empty"
	build_release_tool
fi
sync_cc_repo
