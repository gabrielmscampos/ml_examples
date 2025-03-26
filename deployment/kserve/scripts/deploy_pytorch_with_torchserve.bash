#!/usr/bin/env bash

set -euo pipefail

source ./utils.bash

tmp_kubeconfigs_path="../tmp_kube_configs"
mkdir -p $tmp_kubeconfigs_path

# Variables
inputs_path="../inputs"
templates_path="../templates"
minio_aws_profile_name="local-minio"
service_account_resource_name="s3-serviceaccount"
minikube_ip=$(minikube ip)
minio_api_node_port=$(kubectl get svc minio-service --namespace minio -o jsonpath='{.spec.ports[?(@.name=="api")].nodePort}')
minio_external_api_url="http://$minikube_ip:$minio_api_node_port"

# Deploy model and make it accessible
service_name="torchserve-v1-example"
s3_model_dir="s3://test-bucket/torchserve-v1-example"
storage_uri="\"s3://test-bucket/torchserve-v1-example\""
host_model_path="$tmp_kubeconfigs_path/torchserve-v1-example"

mkdir -p "$host_model_path/model-store"
mkdir -p "$host_model_path/config"

torch-model-archiver \
    --version 1.0 \
    --model-name my_model \
    --serialized-file ../../../models/torch/state_dict.pth \
    --model-file ../../torchserve/my_model.py \
    --handler ../../torchserve/my_handler_kserve.py \
    --export-path "$host_model_path/model-store" \
    --force

cat >"$host_model_path/config/config.properties" <<EOL
inference_address=http://0.0.0.0:8085
management_address=http://0.0.0.0:8085
metrics_address=http://0.0.0.0:8082
grpc_inference_port=7070
grpc_management_port=7071
enable_metrics_api=true
metrics_format=prometheus
number_of_netty_threads=4
job_queue_size=10
enable_envvars_config=true
install_py_dep_per_model=true
model_store=/mnt/models/model-store
model_snapshot={"name":"startup.cfg","modelCount":1,"models":{"my_model":{"1.0":{"defaultVersion":true,"marName":"my_model.mar","minWorkers":1,"maxWorkers":5,"batchSize":1,"maxBatchDelay":10,"responseTimeout":300}}}}
EOL

aws s3 cp --recursive "$host_model_path" $s3_model_dir --profile $minio_aws_profile_name --endpoint-url=$minio_external_api_url &> /dev/null

sed -e "s/{{ inference_service_resource_name }}/$service_name/g" \
    -e "s/{{ service_account_resource_name }}/$service_account_resource_name/g" \
    -e "s|{{ s3_model_root_path }}|$storage_uri|g" \
    $templates_path/torchserve/torchserve_v1.yaml \
    > $tmp_kubeconfigs_path/torchserve-v1-isvc.yaml

deploy_service "default" "$tmp_kubeconfigs_path/torchserve-v1-isvc.yaml" "$service_name"
wait_for_inference_service 300 5 "$service_name" "default"

# Test predictions
istio_node_port=$(kubectl get svc istio-ingressgateway --namespace istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
istio_base_url="http://$minikube_ip:$istio_node_port"
model_name="my_model"
service_name="torchserve-v1-example"
namespace="default"
url="${istio_base_url}/v1/models/${model_name}:predict"
service_hostname=$(kubectl get inferenceservice ${service_name} --namespace "$namespace" -o jsonpath='{.status.url}' | cut -d "/" -f 3)
input_path=@$inputs_path/torchserve_inputs.json
curl -v -H "Host: ${service_hostname}" -H "Content-Type: application/json" $url -d $input_path