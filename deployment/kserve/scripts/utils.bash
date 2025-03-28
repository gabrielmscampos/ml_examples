#!/usr/bin/env bash
#
# Credits: https://github.com/pytorch/serve/blob/master/kubernetes/kserve/tests/scripts/test_mnist.sh
#
# minikube dashboard

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

function wait_for_inference_service() {
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

function _wait_for_inferenceservice_pod_running_http() {
    url="$1"
    cacert="$2"
    cert="$3"
    key="$4"
    namespace="$5"
    service_name="$6"
    max_wait_time="$7"
    interval=5
    start_time=$(date +%s)

    # First wait for pod to exist
    pod_name=""
    while [[ -z "$pod_name" ]]; do
        sleep "$interval"
        echo "Looking for pod for InferenceService $service_name..."

        # Add --verbose to curl for debugging if needed
        pod_name=$(curl --silent --fail \
            --cacert "$cacert" \
            --cert "$cert" \
            --key "$key" \
            "$url/api/v1/namespaces/$namespace/pods" | \
            jq -r ".items[] | select(.metadata.labels.\"serving.kserve.io/inferenceservice\" == \"$service_name\") | .metadata.name")

        # Check timeout
        if (( $(date +%s) - start_time >= max_wait_time )); then
            echo "Timeout waiting for pod to be created for $service_name"
            _delete_minikube_cluster
            exit 1
        fi
    done

    while true; do
        sleep "$interval"
        echo "Checking if pod ${pod_name} is running..."
        pod_status=$(curl --silent --fail \
            --cacert "$cacert" \
            --cert "$cert" \
            --key "$key" \
            $url/api/v1/namespaces/$namespace/pods/$pod_name | jq -r ".status.phase")
        if [[ "$pod_status" == "Running" ]]; then
            echo "${pod_name} pod is running, exiting _wait_for_inferenceservice_pod_running_http."
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

function deploy_inferenceservice_http() {
    url="$1"
    cacert="$2"
    cert="$3"
    key="$4"
    namespace="$5"
    service_yaml_file="$6"
    service_name="$7"

    echo "Deploying the inferenceservice"
    curl --silent --fail \
        --cacert "$cacert" \
        --cert "$cert" \
        --key "$key" \
        -X POST \
        -H 'Content-Type: application/yaml' \
        $url/apis/serving.kserve.io/v1beta1/namespaces/$namespace/inferenceservices \
        --data-binary @$service_yaml_file

    echo "Waiting for pod to come up..."
    _wait_for_inferenceservice_pod_running_http "$url" "$cacert" "$cert" "$key" "$namespace" "$service_name" 300
}

function wait_for_inference_service_http() {
    echo "Wait for inference service to be ready"
    url="$1"
    cacert="$2"
    cert="$3"
    key="$4"
    max_wait_time="$5"
    interval="$6"
    service_name="$7"
    namespace="$8"
    start_time=$(date +%s)
    while true; do
        echo "Checking if service ${service_name} is running..."
        service_status=$(curl --silent --fail \
            --cacert "$cacert" \
            --cert "$cert" \
            --key "$key" \
            $url/apis/serving.kserve.io/v1beta1/namespaces/default/inferenceservices/$service_name | jq -r '.status.conditions[] | select(.type == "Ready") | .status')
        if [[ "$service_status" == "True" ]]; then
            echo "${service_name} service is running, exiting wait_for_inference_service_http."
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