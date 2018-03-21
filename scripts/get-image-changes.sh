#!/bin/bash
set -e
script_dir=$(dirname "$0")
#source versions.txt to know the current image version
source "${script_dir}/../versions.txt"
#Dont consider the current Kata Linux version
(( FROM=${clear_vm_image_version} + 10 ))
TO=$1

usage() {
	cat << EOT
Usage:
$0 <clear-linux-version> > changes

Script to generate list of changed packages that are used in 
Kata Containers image (from the Kata Linux release notes).

EOT
	exit
}

[ -n "${TO}" ] || usage

pkgs="clear-containers-agent|systemd|iptables|coreutils"
pkgs_regex='Changes in package ('"${pkgs}"') \(.*\):(\n.*-.*)*'

#Kata Linux releases are incremented by 10
for (( ver = $FROM ; ver <= ${TO} ; ver+=10 )) do
	echo "Check for changes in version ${ver}" >&2
	url="https://download.clearlinux.org/releases/${ver}/clear/RELEASENOTES"
	changes=$(curl -s $url | pcregrep -M "${pkgs_regex}" ) || true
	if [ -n "${changes}" ]; then
		echo version: ${ver}
		echo "${changes}"
		echo "${url}"
	fi
done
