#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

supported_artifacts=(
  "install_image"
  "install_kata_components"
  "install_experimental_kernel"
  "install_kernel"
  "install_qemu"
  "install_qemu_virtiofsd"
  "install_firecracker"
  "install_docker_config_script"
)

for c in ${supported_artifacts[@]}; do echo $c; done
