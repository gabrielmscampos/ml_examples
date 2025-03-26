#!/usr/bin/env bash

set -euo pipefail

source ./deploy_cluster.bash
source ./deploy_s3_resources.bash
source ./deploy_tensorflow_with_tfserving.bash
source ./deploy_pytorch_model.bash
source ./deploy_xgboost_model.bash
source ./deploy_lightgbm_model.bash
source ./deploy_scikit_model.bash