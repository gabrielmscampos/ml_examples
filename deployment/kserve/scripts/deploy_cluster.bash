#!/usr/bin/env bash

set -euo pipefail

source ./utils.bash

# Create cluster and install KServe
start_minikube_cluster "kserve-test"
install_kserve
minikube_ip=$(minikube ip)

# Deploy minio
kube_yaml="../minio.yaml"
service_name="minio"
deploy_service "minio" "$kube_yaml" "$service_name"
minio_web_node_port=$(kubectl get svc minio-service --namespace minio -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}')
minio_external_web_url="http://$minikube_ip:$minio_web_node_port"
echo "Minio WEB UI available at: ${minio_external_web_url}"