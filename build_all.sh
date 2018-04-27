#!/bin/bash
set -e 
set -x

script_dir=$(dirname "$0")
projects=(
runtime/
)
#proxy/
#shim/
#kata-containers-image/
#kernel/
#ksm-throttler/
#qemu-lite/
#qemu-vanilla/

OSCRC="${HOME}/.oscrc"

export BUILD_DISTROS=${BUILD_DISTROS:-xUbuntu_16.04}

cd $script_dir

OBS_API="https://api.opensuse.org"

if [ -n "${OBS_USER}" ] && [ -n "${OBS_PASS}" ] && [ ! -e "${OSCRC}" ]; then
	echo "Creating  ${OSCRC} with user $OBS_USER"
	cat << eom > ${OSCRC}
[general]
apiurl = ${OBS_API}
[${OBS_API}]
user = ${OBS_USER}
pass = ${OBS_PASS}
eom
fi

for p in "${projects[@]}"; do
	pushd $p >> /dev/null
	echo "update ${p}"
	bash ./update.sh -l -v
	popd >> /dev/null
done
