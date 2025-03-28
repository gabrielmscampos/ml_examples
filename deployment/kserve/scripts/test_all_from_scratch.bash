#!/usr/bin/env bash

set -euo pipefail

source ./deploy_cluster.bash
source ./deploy_s3_resources.bash
source ./deploy_tensorflow_with_tfserving.bash
source ./deploy_pytorch_with_torchserve.bash
source ./deploy_xgboost_with_mlserver.bash
source ./deploy_lightgbm_with_mlserver.bash
source ./deploy_scikit_with_mlserver.bash
source ./deploy_onnx_pytorch_with_tritonserver.bash
source ./deploy_onnx_tensorflow_with_tritonserver.bash
source ./deploy_tensorflow_with_tritonserver.bash
source ./deploy_torchscript_with_tritonserver.bash