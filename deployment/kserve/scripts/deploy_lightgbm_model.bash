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
service_name="lightgbm-example"
s3_model_dir="s3://test-bucket/lightgbm-example"
storage_uri="\"s3://test-bucket/lightgbm-example\""
host_model_path="$tmp_kubeconfigs_path/lightgbm-example"

mkdir -p "$host_model_path"

cp ../../../models/lightgbm_regressor/model.joblib $host_model_path/model.joblib
cp ../../lightgbm_regressor/my_handler.py $host_model_path/my_handler.py
cat >"$host_model_path/model-settings.json" <<EOL
{
  "name": "my_model",
  "implementation": "my_handler.MyModelHandler",
  "parameters": {
    "uri": "./model.joblib",
    "version": "0.1.0"
  }
}
EOL

aws s3 cp --recursive "$host_model_path" $s3_model_dir --profile $minio_aws_profile_name --endpoint-url=$minio_external_api_url &> /dev/null

sed -e "s/{{ inference_service_resource_name }}/$service_name/g" \
    -e "s/{{ service_account_resource_name }}/$service_account_resource_name/g" \
    -e "s|{{ s3_model_root_path }}|$storage_uri|g" \
    $templates_path/lightgbm.yaml \
    > $tmp_kubeconfigs_path/lightgbm-isvc.yaml

deploy_service "default" "$tmp_kubeconfigs_path/lightgbm-isvc.yaml" "$service_name"
wait_for_inference_service 300 5 "$service_name" "default"

# Test predictions
istio_node_port=$(kubectl get svc istio-ingressgateway --namespace istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
istio_base_url="http://$minikube_ip:$istio_node_port"
model_name="my_model"
service_name="lightgbm-example"
namespace="default"
url="${istio_base_url}/v2/models/${model_name}/infer"
service_hostname=$(kubectl get inferenceservice ${service_name} --namespace "$namespace" -o jsonpath='{.status.url}' | cut -d "/" -f 3)
input_path=@$inputs_path/oip_inputs.json
curl -v -H "Host: ${service_hostname}" -H "Content-Type: application/json" $url -d $input_path