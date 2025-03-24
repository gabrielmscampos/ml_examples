#!/usr/bin/env bash

set -euo pipefail

tmp_kubeconfigs_path="../tmp_kube_configs"
mkdir -p $tmp_kubeconfigs_path

# Variables
templates_path="../templates"
minio_aws_profile_name="local-minio"
minio_aws_access_key_id="minio"
minio_aws_secret_access_key="minio123"

# Configure aws profile for local-minio and create a test-bucket
minikube_ip=$(minikube ip)
minio_api_node_port=$(kubectl get svc minio-service --namespace minio -o jsonpath='{.spec.ports[?(@.name=="api")].nodePort}')
minio_external_api_url="http://$minikube_ip:$minio_api_node_port"
aws configure set aws_access_key_id $minio_aws_access_key_id --profile $minio_aws_profile_name
aws configure set aws_secret_access_key $minio_aws_secret_access_key --profile $minio_aws_profile_name
aws s3api create-bucket --bucket test-bucket --profile $minio_aws_profile_name --endpoint-url=$minio_external_api_url &> /dev/null

# Create S3 secrets and service account to access minio
secret_resource_name="s3-creds"
s3_use_https="\"0\""
s3_use_anon_credential="\"false\""
service_account_resource_name="s3-serviceaccount"
minio_api_cluster_ip=$(kubectl get svc minio-service --namespace minio -o jsonpath='{.spec.clusterIP}')
minio_internal_api_uri="$minio_api_cluster_ip:9000"
sed -e "s/{{ secret_resource_name }}/$secret_resource_name/g" \
    -e "s/{{ s3_endpoint_url }}/$minio_internal_api_uri/g" \
    -e "s/{{ s3_use_https }}/$s3_use_https/g" \
    -e "s/{{ s3_use_anon_credential }}/$s3_use_anon_credential/g" \
    -e "s/{{ aws_access_key_id }}/$minio_aws_access_key_id/g" \
    -e "s/{{ aws_secret_access_key }}/$minio_aws_secret_access_key/g" \
    -e "s/{{ service_account_resource_name }}/$service_account_resource_name/g" \
    $templates_path/service_account_for_s3.yaml \
    > $tmp_kubeconfigs_path/service_account_for_s3.yaml
kubectl apply -f $tmp_kubeconfigs_path/service_account_for_s3.yaml --namespace default