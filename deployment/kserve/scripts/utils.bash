#!/usr/bin/env bash
#
# Credits: https://github.com/pytorch/serve/blob/master/kubernetes/kserve/tests/scripts/test_mnist.sh
#
# minikube dashboard

set -euo pipefail

function start_minikube_cluster() {
    profile_name="$1"
    echo "Checking if Minikube profile '$profile_name' exists..."
    if minikube profile list | grep -q "$profile_name"; then
        echo "Profile '$profile_name' exists. Deleting it..." 
        minikube delete -p "$profile_name"
    fi
    echo "Starting new Minikube cluster with profile '$profile_name'"
    minikube start -p "$profile_name"
    echo "Installing metrics-server addon"
    minikube addons enable metrics-server -p "$profile_name"
    echo "Activating profile $profile_name"
    minikube profile $profile_name
}

function _delete_minikube_cluster() {
    echo "Deleting cluster"
    minikube delete
}

function _wait_for_kserve_pod() {
    max_wait_time="$1"
    interval="$2"
    start_time=$(date +%s)
    while true; do
        echo "Checking if kserver pod is running..."
        kserve_pod_status=$(kubectl get pods --namespace kserve --no-headers -o custom-columns=":status.phase")
        if [[ "$kserve_pod_status" == "Running" ]]; then
            echo "kserve pod is running, exiting wait_for_kserve_pod."
            break
        fi
        current_time=$(date +%s)
        if (( current_time - start_time >= max_wait_time )); then
            echo "Timeout waiting for Kserve pod to come up."
            _delete_minikube_cluster
            exit 1
        fi
        sleep "$interval"
    done
}

function install_kserve() {
    echo "Installing Kserve"
    git clone https://github.com/kserve/kserve kserve_repo
    cd kserve_repo
    ./hack/quick_install.sh
    echo "Waiting for Kserve pod to come up ..."
    _wait_for_kserve_pod 300 5
    cd .. && rm -rf kserve_repo
}

function _wait_for_pod_running() {
    namespace="$1"
    pod_name="$2"
    max_wait_time="$3"
    interval=5
    start_time=$(date +%s)
    while true; do
        sleep "$interval"
        echo "Checking if pod ${pod_name} is running..."
        pod_description=$(kubectl describe pod "$pod_name" --namespace "$namespace" )
        status_line=$(echo "$pod_description" | grep -E "Status:")
        pod_status=$(echo "$status_line" | awk '{print $2}')
        if [[ "$pod_status" == "Running" ]]; then
            echo "${pod_name} pod is running, exiting wait_for_pod_running."
            break
        fi
        current_time=$(date +%s)
        if (( current_time - start_time >= max_wait_time )); then
            echo "Timeout waiting for pod $pod_name to become Running."
            _delete_minikube_cluster
            exit 1
        fi
    done
}

function deploy_service() {
    namespace="$1"
    service_yaml_file="$2"
    service_name="$3"
    echo "Deploying the cluster"
    kubectl apply -f "$service_yaml_file" --namespace "$namespace"
    echo "Waiting for pod to come up..."
    _wait_for_pod_running "$namespace" "$service_name" 300
}

function deploy_service_from_str() {
    namespace="$1"
    service_yaml_str="$2"
    service_name="$3"
    echo "Deploying the cluster"
    echo "$service_yaml_str" | kubectl --namespace "$namespace" apply -f -
    echo "Waiting for pod to come up..."
    _wait_for_pod_running "$namespace" "$service_name" 300
}

function _wait_for_inference_service() {
    echo "Wait for inference service to be ready"
    max_wait_time="$1"
    interval="$2"
    service_name="$3"
    namespace="$4"
    start_time=$(date +%s)
    while true; do
        echo "Checking if service ${service_name} is running..."
        service_status=$(kubectl get inferenceservice ${service_name} --namespace "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        if [[ "$service_status" == "True" ]]; then
            echo "${service_name} service is running, exiting wait_for_inference_service."
            break
        fi
        current_time=$(date +%s)
        if (( current_time - start_time >= max_wait_time )); then
            echo "Timeout waiting for inference service to come up."
            _delete_minikube_cluster
            exit 1
        fi
        sleep "$interval"
    done
}

function make_isvc_accessible() {
    namespace="$1"
    service_name="$2"
    _wait_for_inference_service 300 5 "$service_name" "$namespace"
    echo "✓ Service is accessible"
}