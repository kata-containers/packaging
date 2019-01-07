#!/bin/sh

set -o errexit
set -o pipefail
set -o nounset

function print_usage_exit() {
	echo "Usage: $0 [install/cleanup]"
	exit 1
}

function get_container_runtime() {
	local runtime=$(kubectl describe node $NODE_NAME)
	echo wtf "$?"
	if [ "$?" -ne 0 ]; then
		echo invalid-node name
		exit
	fi
	echo "$runtime" | awk -F'[:]' '/Container Runtime Version/ {print $2}' | tr -d ' '
}

function install_artifacts() {
	echo "copying kata artifacts onto host"
	cp -R /opt/kata-artifacts/opt/kata/* /opt/kata/
	chmod +x /opt/kata/bin/*
	#TODO: hack in the firecracker indirection runtime...

	cat <<EOT | sudo tee /usr/bin/kata-fc
#!/bin/bash

/opt/kata/bin/kata-runtime --kata-config /opt/kata/share/defaults/kata-containers/configuration_fc.toml "\$@"
EOT

	sudo chmod +x /usr/bin/kata-fc

}

function configure_crio() {
	# Configure crio to use Kata:
	echo "Add Kata Containers as a supported runtime:"
	# backup the CRIO.conf only if a backup doesn't already exist (don't override original)
	if [ ! -f /etc/crio/crio.conf.bak ]; then
		cp /etc/crio/crio.conf /etc/crio/crio.conf.bak
	fi
	echo -e "\n[crio.runtime.runtimes.kata-qemu]\nruntime_path = \"/opt/kata/bin/kata-qemu\"" >>/etc/crio/crio.conf
	echo -e "\n[crio.runtime.runtimes.kata-fc]\nruntime_path = \"/opt/kata/bin/kata-fc\"" >>/etc/crio/crio.conf
	sed -i 's|\(\[crio\.runtime\]\)|\1\nmanage_network_ns_lifecycle = true|' /etc/crio/crio.conf

	systemctl daemon-reload
	systemctl restart crio
}

function configure_containerd() {
	# Configure containerd to use Kata:
	echo "create containerd configuration for Kata"
	mkdir -p /etc/containerd/

	if [ -f /etc/containerd/config.toml ]; then
		cp /etc/containerd/config.toml /etc/containerd/config.toml.bak
	fi
	# TODO: THIS IS REALLY BAD - SAI HELP!
	cat <<EOT | tee /etc/containerd/config.toml
[plugins]
    [plugins.cri.containerd]
      [plugins.cri.containerd.untrusted_workload_runtime]
        runtime_type = "io.containerd.runtime.v1.linux"
        runtime_engine = "/opt/kata/bin/kata-runtime"
        runtime_root = ""
EOT
	systemctl daemon-reload
	systemctl restart containerd
}

function action_crio() {
	case $1 in
	install)
		install_artifacts
		configure_crio

		;;
	cleanup)
		echo cleanup_crio
		;;
	*)
		echo unsupported action: $1
		;;
	esac
}

function action_containerd() {
	case $1 in
	install)
		echo install_containerd
		install_artifacts
		configure_containerd
		;;
	cleanup)
		echo cleanup_containerd
		;;
	*)
		echo unsupported action: $1
		;;
	esac
}

function remove_artifacts() {
	echo "deleting kata artifacts"
	rm -rf /opt/kata/
}

function reset_crio() {
	if [ -f /etc/crio/crio.conf.bak ]; then
		mv /etc/crio/crio.conf.bak /etc/crio/crio.conf
	fi
}

function reset_containerd() {
	rm -f /etc/containerd/config.toml
	if [ -f /etc/containerd/config.toml.bak ]; then
		mv /etc/containerd/config.toml.bak /etc/containerd/config.toml
	fi

}

function action() {
	runtime=$(get_container_runtime)

	case $runtime in
	cri-o)
		action_crio $1
		;;
	containerd)
		action_containerd $1
		;;
	*)
		echo unsupported CRI runtime: $runtime
		;;
	esac
	sleep infinity
}

action $1
