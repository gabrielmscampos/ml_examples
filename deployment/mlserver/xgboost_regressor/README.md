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
cp ../../../models/xgb_regressor/0001.ubj my_model/0001.ubj
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
python test_predictions.py -r 360950
```

## Test predictions on a different server

If using `minikube` to deploy the xgboost model using MLServer behind KServe, you can use the same script to test predictions:

```bash
python test_predictions.py \
  -r 360950 \
  -u "http://$(minikube ip):$(kubectl get svc istio-ingressgateway --namespace istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')/v2/models/my_model/infer" \
  -H "Host=$(kubectl get inferenceservice xgboost-v2-example --namespace default -o jsonpath='{.status.url}' | cut -d "/" -f 3)"
```