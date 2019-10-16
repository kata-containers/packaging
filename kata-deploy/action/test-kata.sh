#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset


function waitForProcess() {
        wait_time="$1"
        sleep_time="$2"
        cmd="$3"
        while [ "$wait_time" -gt 0 ]; do
                if eval "$cmd"; then
                        return 0
                else
                        sleep "$sleep_time"
                        wait_time=$((wait_time-sleep_time))
                fi
        done
        return 1
}



function run_test() {
	PKG_SHA=$1
	YAMLPATH="https://raw.githubusercontent.com/amshinde/kata-packaging/$PKG_SHA/kata-deploy"
	echo "verify connectivity with a pod using Kata"

	deployment=""
	busybox_pod="test-nginx"
	busybox_image="busybox"
	cmd="kubectl get pods | grep $busybox_pod | grep Completed"
	wait_time=120
	sleep_time=3

        configurations=("nginx-deployment-qemu" "nginx-deployment-qemu-virtiofs" "nginx-deployment-nemu")
        for deployment in "${configurations[@]}"; do
	  # start the kata pod:
	  kubectl apply -f "$YAMLPATH/examples/${deployment}.yaml"
	  kubectl wait --timeout=5m --for=condition=Available deployment/${deployment}
	  kubectl expose deployment/${deployment}

	  # test pod connectivity:
	  kubectl run $busybox_pod --restart=Never --image="$busybox_image" -- wget --timeout=5 "$deployment"
	  waitForProcess "$wait_time" "$sleep_time" "$cmd"
	  kubectl logs "$busybox_pod" | grep "index.html"
	  kubectl describe pod "$busybox_pod"

	  # cleanup:
	  kubectl delete deployment "$deployment"
	  kubectl delete service "$deployment"
	  kubectl delete pod "$busybox_pod"
	done
}


function test_kata() {
	set -x
	echo "hello"
	echo "$PKG_SHA"
	#kubectl all the things
	kubectl get pods --all-namespaces

	YAMLPATH="https://raw.githubusercontent.com/amshinde/kata-packaging/$PKG_SHA/kata-deploy"
	
	kubectl apply -f "$YAMLPATH/kata-rbac.yaml"
	# apply runtime classes:
	kubectl apply -f "$YAMLPATH/k8s-1.14/kata-nemu-runtimeClass.yaml"
	kubectl apply -f "$YAMLPATH/k8s-1.14/kata-qemu-runtimeClass.yaml"
	kubectl apply -f "$YAMLPATH/k8s-1.14/kata-qemu-virtiofs-runtimeClass.yaml"
	kubectl apply -f "$YAMLPATH/k8s-1.14/kata-fc-runtimeClass.yaml"

	sleep 5

	kubectl get runtimeclasses

	wget "$YAMLPATH/kata-deploy.yaml"
	wget "$YAMLPATH/kata-cleanup.yaml"

	# update deployment daemonset to utilize the container under test:
	sed -i "s#katadocker/kata-deploy#katadocker/kata-deploy-ci:${PKG_SHA}#g" kata-deploy.yaml
	sed -i "s#katadocker/kata-deploy#katadocker/kata-deploy-ci:${PKG_SHA}#g" kata-cleanup.yaml

	cat kata-deploy.yaml

	sleep 100

	# deploy kata:
	kubectl apply -f kata-deploy.yaml

	sleep 100

	#wait for kata-deploy to be up
	kubectl -n kube-system wait --timeout=5m --for=condition=Ready -l name=kata-deploy pod

	#Do I see this?
	kubectl get pods --all-namespaces --show-labels
	kubectl get node --show-labels

	run_test $PKG_SHA

	kubectl get nodes --show-labels
	# remove kata (yeah, we are about to destroy, but good to test this flow as well):
	kubectl delete -f kata-deploy.yaml
	kubectl -n kube-system wait --timeout=5m --for=delete -l name=kata-deploy pod

	kubectl get nodes --show-labels

	kubectl apply -f kata-cleanup.yaml

	sleep 20

	kubectl get pods --all-namespaces --show-labels
	kubectl get node --show-labels

	kubectl delete -f kata-cleanup.yaml

	rm kata-cleanup.yaml
	rm kata-deploy.yaml

	set +x
}
