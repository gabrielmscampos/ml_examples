# Scikit-learn deployment test

KServe under the hood is using MLServer runtime by default under the V2 protocol, however you can choose the KServe Sklearn Server (kserve-sklearnserver) runtime for serving the model as well. You can read more about MLServer [here](https://mlserver.readthedocs.io/en/stable/getting-started/index.html) and KServe Sklearn Server [here](https://kserve.github.io/website/0.14/modelserving/v1beta1/sklearn/v2/#test-the-model-locally).

For this example, using MLServer instead of sklearnserver for serving our Scikit-Learn model in KServe provides more flexibility, especially for handling our custom transformer Preprocessing and our custom regressor NMFRegressor.

## Exporting the model

Run the `notebooks/scikit_custom_regressor.ipynb` notebook to have the model exported.

## Package the model

### Default SKLearnModel implementation

Ensure your model is saved in a directory with the correct MLServer format:

```shell
model_store/
│── settings.json        # Optional general configuration
│── model-settings.json  # MLServer configuration
│── model.joblib         # Saved Scikit-Learn model
```

If you are using the default scikit-learn implementation (`mlserver_sklearn.SKLearnModel`) in `model-settings.json`, you are good to go. A `model-settings.json` like this would be enough:

```json
{
  "name": "my_model",
  "implementation": "mlserver_sklearn.SKLearnModel",
  "parameters": {
    "uri": "./model.joblib"
  }
}
```

Note: your model cannot depend on custom objects outside scikit-learn.

### Custom implementation

Since we depend on `Preprocessing` and `NMFRegressor` custom objects, we will define those objects in a dedicated `my_model.py` and instruct MLServer to run our model with a custom implementation in `my_handler.py`.

For this example, you can run:

```bash
mkdir -p my_model
cp ../../models/scikit_custom_regressor/model.joblib my_model
cp ./my_handler.py my_model/my_handler.py
cp ./my_model.py my_model/my_model.py
cat >./my_model/model-settings.json <<EOL
{
  "name": "my_model",
  "implementation": "my_handler.MyModelHandler",
  "parameters": {
    "uri": "./model.joblib",
    "version": "0.1.0"
  }
}
EOL
```

## Start serving

Using docker you can start serving a scikit-learn model using the following command:

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

### Building sklearnserver with docker

Since `sklearnserver` depends on `kserve[storage]` which depends on `protobuf (^4.25.4)`, installing `sklearnserver` using pip or poetry in this project will lead to dependency incompatiblity. Since, this project depends on `tf2onnx (1.16.1)` (for testing tensorflow expert to ONNX) which depends on `protobuf (>=3.20,<4.0)`. Therefore, the easiest way to test locally is to build the xgbsersklearnserverver using docker.

```bash
git clone https://github.com/kserve/kserve
cd kserve/python/
docker build -t sklearnserver -f sklearn.Dockerfile .
```

### Serving with sklearnserver

Be sure that your model doesn't need any custom dependencies, otherwise you'll have to modify the sklearn.Dockerfile and build a custom image for you model.

```bash
docker run -it --rm \
    -p 8080:8080 \
    --name=sklearnserver \
    --mount type=bind,source=$(pwd)/models,target=/models \
    sklearnserver \
    python -m sklearnserver --model_dir=/models/scikit_custom_regressor --model_name=scikit_custom_regressor
```