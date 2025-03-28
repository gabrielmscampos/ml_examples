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
service_name="tensorflow-tritonserver-example"
s3_model_dir="s3://test-bucket/tensorflow-tritonserver-example/my_model"
storage_uri="\"s3://test-bucket/tensorflow-tritonserver-example\""
host_model_path="$tmp_kubeconfigs_path/tensorflow-tritonserver-example/my_model"

mkdir -p "$host_model_path"
mkdir -p "$host_model_path/1"

cp -r ../../../models/tensorflow/1 $host_model_path/1/model.savedmodel/
cat >"$host_model_path/config.pbtxt" <<EOL
name: "my_model"
platform: "tensorflow_savedmodel"
max_batch_size: 0
input [
  {
    name: "input_0"
    data_type: TYPE_FP32
    dims: [-1, 51]
  }
]
output [
  {
    name: "output_0"
    data_type: TYPE_FP32
    dims: [-1, 51]
  },
  {
    name: "output_1"
    data_type: TYPE_FP32
    dims: [-1]
  }
]
EOL

aws s3 cp --recursive "$host_model_path" $s3_model_dir --profile $minio_aws_profile_name --endpoint-url=$minio_external_api_url &> /dev/null

sed -e "s/{{ inference_service_resource_name }}/$service_name/g" \
    -e "s/{{ service_account_resource_name }}/$service_account_resource_name/g" \
    -e "s|{{ s3_model_root_path }}|$storage_uri|g" \
    $templates_path/tritonserver/tensorflow.yaml \
    > $tmp_kubeconfigs_path/tensorflow-tritonserver-example-isvc.yaml

deploy_service "default" "$tmp_kubeconfigs_path/tensorflow-tritonserver-example-isvc.yaml" "$service_name"
wait_for_inference_service 300 5 "$service_name" "default"

# Test predictions
istio_node_port=$(kubectl get svc istio-ingressgateway --namespace istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
istio_base_url="http://$minikube_ip:$istio_node_port"
model_name="my_model"
service_name="tensorflow-tritonserver-example"
namespace="default"
url="${istio_base_url}/v2/models/${model_name}/infer"
service_hostname=$(kubectl get inferenceservice ${service_name} --namespace "$namespace" -o jsonpath='{.status.url}' | cut -d "/" -f 3)

# Test without optional outputs
temp_file=$(mktemp)
jq '.inputs[].name |= sub("input-0"; "input_0")' $inputs_path/oip_inputs.json > $temp_file
curl -v -H "Host: ${service_hostname}" -H "Content-Type: application/json" $url -d @$temp_file
rm $temp_file

# Test with optional outputs
temp_file=$(mktemp)
jq '
  .inputs[].name |= sub("input-0"; "input_0") |
  .outputs[].name |= sub("reconstructed"; "output_0") |
  .outputs[].name |= sub("avg_mse"; "output_1")
' $inputs_path/oip_inputs_outputs.json > $temp_file
curl -v -H "Host: ${service_hostname}" -H "Content-Type: application/json" $url -d @$temp_file
rm $temp_file