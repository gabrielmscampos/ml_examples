# XGBoost deployment test

KServe under the hood is using MLServer runtime by default under the V2 protocol, however you can choose the KServe XGBoost Server (kserve-sklearnserver) runtime for serving the model as well. You can read more about MLServer [here](https://mlserver.readthedocs.io/en/stable/getting-started/index.html) and KServe XGBoost Server [here](https://kserve.github.io/website/0.14/modelserving/v1beta1/xgboost/#test-the-model-locally).

For this example, using MLServer instead of xgboostserver for serving our XGBoost model in KServe provides more flexibility, especially if we want to handle a custom runtime.

## Exporting the model

Run the `notebooks/scikit_custom_regressor.ipynb` notebook to have the model exported.

## Package the model

### Default XGBoostModel implementation

Ensure your model is saved in a directory with the correct MLServer format:

```shell
model_store/
│── settings.json        # Optional general configuration
│── model-settings.json  # MLServer configuration
│── 0001.ubj             # Saved XGBoost model
```

If you are using the default xgboost implementation (`mlserver_sklearn.XGBoostModel`) in `model-settings.json`, you are good to go. A `model-settings.json` like this would be enough:

```json
{
  "name": "my_model",
  "implementation": "mlserver_xgboost.XGBoostModel",
  "parameters": {
    "uri": "./0001.ubj"
  }
}
```

Note: your model cannot depend on custom objects not present in the default implementation.

### Custom implementation

Since our model is only outputing the reconstructed inputs, we need to pre-process the inputs and compute the MSE after the predictions. We will define all those steps in `my_handler.py` that will be used by MLServer to serve the model.

For this example, you can run:

```bash
mkdir -p my_model
cp ../../models/xgb_regressor/0001.ubj my_model/0001.ubj
cp ./my_handler.py my_model/my_handler.py
cat >./my_model/model-settings.json <<EOL
{
  "name": "my_model",
  "implementation": "my_handler.MyModelHandler",
  "parameters": {
    "uri": "./0001.ubj",
    "version": "0.1.0"
  }
}
EOL
```

## Start serving

Using docker you can start serving a xgboost model using the following command:

```bash
docker run --rm \
    -p 8080:8080 \
    -v $(pwd)/my_model:/mnt/my_model \
    seldonio/mlserver:1.6.1 mlserver start /mnt/my_model
```

You can test if your model was correctly loaded using:

```bash
curl http://localhost:8080/v2/models/my_model
```

## Test predictions

Run the test predictions script to test if your model working correctly with MLServer:

```bash
python test_predictions.py 360950
```

## Other material

### Building xgbserver with docker

Since `xgbserver` depends on `kserve[storage]` which depends on `protobuf (^4.25.4)`, installing `xgbserver` using pip or poetry in this project will lead to dependency incompatiblity. Since, this project depends on `tf2onnx (1.16.1)` (for testing tensorflow expert to ONNX) which depends on `protobuf (>=3.20,<4.0)`. Therefore, the easiest way to test locally is to build the xgbserver using docker.

```bash
git clone https://github.com/kserve/kserve
cd kserve/python/
docker build -t xgbserver -f xgb.Dockerfile .
```

### Serving with xgbserver

Be sure that your model doesn't need any custom dependencies, otherwise you'll have to modify the sklearn.Dockerfile and build a custom image for you model.

```bash
docker run -it --rm \
    -p 8080:8080 \
    --name=xgbserver \
    --mount type=bind,source=$(pwd)/../../models/xgb_regressor,target=/models/my_model \
    xgbserver \
    python -m xgbserver --model_dir=/models/my_model --model_name=my_model
```