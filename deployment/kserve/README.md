# KServe deployment test

## Cluster

Provided you have `minikube`, `kubectl` and `helm` installed, you can deploy a local cluster with KServe and minio using:

```shell
cd scripts && ./deploy_cluster.bash
```

## S3 resources

Minio is deployed with credentials `minio:minio123`, but we still have to configure a service account in our cluster that is capable of using those credentials to authenticate against Minio and fetch models during kserve storage container initialization. You can do it using the following script:

```shell
cd scripts && ./deploy_s3_resources.bash
```

## Model deployment

- tensorflow: `cd scripts && ./deploy_tensorflow_model.bash`