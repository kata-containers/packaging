#!/bin/bash

set -x

create_cloud_init_file() {
	file="$1"
	#ssh_pub_key_file="$2"
	#ssh_pub_key="$(cat "${ssh_pub_key_file}")"
	apt_proxy=""
	docker_proxy=""
	docker_user_proxy=""
	environment=$(env | egrep "ghprb|WORK|KATA|GIT|JENKINS|_PROXY|_proxy" | \
	                    sed -e "s/'/'\"'\"'/g" \
	                        -e "s/\(^[[:alnum:]_]\+\)=/\1='/" \
	                        -e "s/$/'/" \
	                        -e 's/^/    export /')

	if [ -n "${http_proxy}" ] && [ -n "${https_proxy}" ]; then
		apt_proxy="    Acquire::http::Proxy \"${http_proxy}\"\;
    Acquire::https::Proxy \"${https_proxy}\"\;"
		docker_proxy='[Service]
    Environment="HTTP_PROXY='${http_proxy}'" "HTTPS_PROXY='${https_proxy}'" "NO_PROXY='${no_proxy}'"'
		docker_user_proxy='{"proxies": { "default": {
    "httpProxy": "'${http_proxy}'",
    "httpsProxy": "'${https_proxy}'",
    "noProxy": "'${no_proxy}'"
    } } }'
	fi

	cat <<EOF > "${file}"
#cloud-config
package_upgrade: false
runcmd:
- touch /.done
write_files:
- content: |
${environment}
  path: /etc/environment
- content: |
${apt_proxy}
  path: /etc/apt/apt.conf.d/proxy.conf
- content: |
    ${docker_proxy}
  path: /etc/systemd/system/docker.service.d/http-proxy.conf
- content: |
    ${docker_user_proxy}
  path: /home/${MULTIPASS_USER}/.docker/config.json
- content: |
    set -x
    set -o errexit
    set -o nounset
    set -o pipefail
    set -o errtrace
    . /etc/environment
    for i in \$(seq 1 20); do
        [ -f /.done ] && break
        echo "waiting for cloud-init to finish"
        sleep 10;
    done

    export CRIO=no
    export CRI_CONTAINERD=no
    export KUBERNETES=no
    export OPENSHIFT=no
    export CI=true
    export SNAP_CI=true
    export GOPATH=\${WORKSPACE}/go
    export PATH=\${GOPATH}/bin:/usr/local/go/bin:/usr/sbin:\${PATH}
    export GOROOT="/usr/local/go"
    export ghprbPullId
    export ghprbTargetBranch

    # Make sure the packages were installed
    # Sometimes cloud-init is unable to install them
    sudo apt update
    sudo apt upgrade -y

    sudo snap set system proxy.http=\${http_proxy}
    sudo snap set system proxy.https=\${https_proxy}

    sudo apt install -y git make snapcraft gcc

    tests_repo_dir="\${GOPATH}/src/github.com/kata-containers/tests"
    mkdir -p "\${tests_repo_dir}"
    git clone https://github.com/kata-containers/tests.git "\${tests_repo_dir}"
    cd "\${tests_repo_dir}"

    trap "cd \${tests_repo_dir}; sudo -E PATH=\$PATH .ci/teardown.sh ${artifacts_dir}; sudo chown -R ${MULTIPASS_USER} ${artifacts_dir}" EXIT

    sudo -E PATH=\$PATH .ci/jenkins_job_build.sh "\$(echo \${GIT_URL} | sed -e 's|https://||' -e 's|.git||')"

  path: /home/${MULTIPASS_USER}/run.sh
  permissions: '0755'
EOF
}

### DEBUG
#export WORKSPACE=/tmp/go
#export ghprbPullId=1069
#export ghprbTargetBranch=master
#export GIT_URL="https://github.com/kata-containers/packaging"
#export CI=true
###

export MULTIPASS_USER=ubuntu
sudo snap install multipass
cinit_file=$(mktemp)
create_cloud_init_file "${cinit_file}"
cat ${cinit_file} | sudo multipass launch -d 10G -c $(nproc) -m 3G -n snapcraft 20.04 -
rm -f "${cinit_file}"
sudo multipass exec snapcraft -- /home/${MULTIPASS_USER}/run.sh
