# Tensorflow deployment test

KServe may use under the hood is using NVIDIA Triton Inference Server for serving the model.

## Exporting the model

Run the `notebooks/tensorflow.ipynb` notebook to have the model exported.

## Package the model

First we have to create a model repository from which tritonserver can find our model. You can read more about it [here](https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/user_guide/model_repository.html#tensorflow-models). It is also mandatory to configure your model after creating the model reposiory, you can read more about it [here](https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/user_guide/model_configuration.html).

For this example, you can run:

```bash
mkdir -p model-repository/my_model/1
cp -r ../../../models/tensorflow/1 model-repository/my_model/1/model.savedmodel/
cat >./model-repository/my_model/config.pbtxt <<EOL
name: "my_model"
platform: "tensorflow_savedmodel"
max_batch_size: 0
input [
  {
    name: "input_0"
    data_type: TYPE_FP32
    dims: [-1, 51]
  }
]
output [
  {
    name: "output_0"
    data_type: TYPE_FP32
    dims: [-1, 51]
  },
  {
    name: "output_1"
    data_type: TYPE_FP32
    dims: [-1]
  }
]
EOL
```

## Start serving

Using docker you can start serving a tensorflow model using the following command:

```bash
docker run --rm \
    -p 8000:8000 \
    -p 8001:8001 \
    -p 8002:8002 \
    -v $(pwd)/model-repository:/models \
    nvcr.io/nvidia/tritonserver:25.02-py3 tritonserver --model-repository=/models
```

You can find other tritonserver releases [here](https://docs.nvidia.com/deeplearning/triton-inference-server/release-notes/index.html).

You can test if your model was correctly loaded using:

```bash
curl http://localhost:8000/v2/models/my_model
```

## Test predictions

Run the test predictions script to test if your model working correctly with tritonserver:

```bash
python test_predictions.py -r 360950
```

## Test predictions on a different server

If using `minikube` to deploy the tensorflow model using tritonserver behind KServe, you can use the same script to test predictions:

```bash
python test_predictions.py \
  -r 360950 \
  -u "http://$(minikube ip):$(kubectl get svc istio-ingressgateway --namespace istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')/v2/models/my_model/infer" \
  -H "Host=$(kubectl get inferenceservice tensorflow-tritonserver-example --namespace default -o jsonpath='{.status.url}' | cut -d "/" -f 3)"
```