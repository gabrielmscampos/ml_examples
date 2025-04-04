# ML Examples

Collection of notebooks implementing different ML models using CMS DQM per-LS data. The purpose of this repository is having different test cases for Kubeflow deployment using the KServe inferenceservices api.

## Notebooks

- [tensorflow](./notebooks/tensorflow.ipynb): Implements a AutoEncoder used to reconstructed the METSig monitoring element.
- [pytorch](./notebooks/pytorch.ipynb): Same as tensorflow, but the following the torch way.
- [xgboost](./notebooks/xgboost.ipynb): Simple supervised tree boosting classifier to spot anomalous lumisections.
- [xgboost_regressor](./notebooks/xgboost_regressor.ipynb): Simple unsupervised tree boosting regressor to reconstruct METSig distributions, the idea behind this is having the same output as an AutoEncoder using boosted trees.
- [lightgbm](./notebooks/lightgbm.ipynb): Simple supervised tree boosting classifier to spot anomalous lumisections.
- [lightgbm_regressor](./notebooks/lightgbm_regressor.ipynb): Same idea as the `xgboost_regressor`. However, using `MultiOutputRegressor` wrapper from `scikit-learn` to generalize the LightGBM booster for multi target output.
- [scikit](./notebooks/scikit.ipynb): Dead simple NMF modeling of the METSig distribution, the ideia is using the NMF method to reconstruct the METSig distributions and spot anomalies.
- [sciki_custom_regressor](./notebooks/scikit_custom_regressor.ipynb): Generalization of the `scikit` notebook implementation using custom objects and `scikit-learn` pipelines.

## Deployment

Directory used to test the local deployment of models using `tf-serving`, `torchserver` and `mlserver`. This is used as a test case to understand how KServe is deploying models under the hood and a way to validate if the model works with the underlying serving framework before deploying it.

- [tfserving](./deployment/tfserving/): Deploys a tensorflow model using `tf-serving`.
- [torchserve](./deployment/torchserve/): Deploys a pytorch model using `torchserve` and a custom inference handler.
- [mlserver/xgboost_regressor](./deployment/mlserver/xgboost_regressor/): Deploys a xgboost model using `mlserver` and a custom inference implementation.
- [mlserver/lightgbm_regressor](./deployment/mlserver/lightgbm_regressor/): Deploys a lightgbm model wrapped with scikit-learn's MultiOutputRegressor using `mlserver` and a custom inference implementation.
- [mlserver/sciki_custom_regressor](./deployment/mlserver/scikit_custom_regressor/): Deploys a scikit-learn model using `mlserver` and a custom inference implementation.
- [tritonserver/onnx/pytorch](./deployment/tritonserver/onnx/pytorch/): Deployes a onnx model exported from pytorch using NVIDIA Triton Inferece Server.
- [tritonserver/onnx/pytorch](./deployment/tritonserver/onnx/pytorch/): Deployes a onnx model exported from tensorflow using NVIDIA Triton Inferece Server.
- [tritonserver/tensorflow](./deployment/tritonserver/tensorflow/): Deployes a tensorflow model using NVIDIA Triton Inferece Server.
- [tritonserver/torchscript](./deployment/tritonserver/torchscript/): Deployes a torchscript model using NVIDIA Triton Inferece Server.

### KServe

Local kserve deployment test is done using `minikube` to deploy a local k8s cluster. More info can be found [here](./deployment/kserve/).