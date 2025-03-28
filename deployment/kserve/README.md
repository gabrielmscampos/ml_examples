# KServe deployment test

Note: all the commands assume that `scripts` is your current working directory.

## Cluster

Provided you have `minikube`, `kubectl` and `helm` installed, you can deploy a local cluster with KServe and minio using:

```shell
./deploy_cluster.bash
```

## S3 resources

Minio is deployed with credentials `minio:minio123`, but we still have to configure a service account in our cluster that is capable of using those credentials to authenticate against Minio and fetch models during kserve storage container initialization. You can do it using the following script:

```shell
./deploy_s3_resources.bash
```

## Model deployment

- tensorflow using `kserve-tensorflow-serving` runtime: `./deploy_tensorflow_with_tfserving.bash`
- pytorch using `kserve-torchserve` runtime: `./deploy_pytorch_with_torchserve.bash`
- xgboost using `kserve-mlserver` runtime: `./deploy_xgboost_with_mlserver.bash`
- lightgbm using `kserve-mlserver` runtime: `./deploy_lightgbm_with_mlserver.bash`
- sklearn using `kserve-mlserver` runtime: `./deploy_scikit_with_mlserver.bash`
- onnx (exported from tensorflow) using `kserve-tritonserver` runtime: `./deploy_onnx_tensorflow_with_tritonserver.bash`
- onnx (exported from pytorch) using `kserve-tritonserver` runtime: `./deploy_onnx_pytorch_with_tritonserver.bash`
- tensorflow using `kserve-tritonserver` runtime: `./deploy_tensorflow_with_tritonserver.bash`
- torchscript using `kserve-tritonserver` runtime: `./deploy_torchscript_with_tritonserver.bash`