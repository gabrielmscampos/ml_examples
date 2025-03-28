#!/usr/bin/env bash

set -euo pipefail

./deploy_cluster.bash
./deploy_s3_resources.bash
./deploy_tensorflow_with_tfserving.bash
./deploy_pytorch_with_torchserve.bash
./deploy_xgboost_with_mlserver.bash
./deploy_lightgbm_with_mlserver.bash
./deploy_scikit_with_mlserver.bash
./deploy_onnx_pytorch_with_tritonserver.bash
./deploy_onnx_tensorflow_with_tritonserver.bash
./deploy_tensorflow_with_tritonserver.bash
./deploy_torchscript_with_tritonserver.bash