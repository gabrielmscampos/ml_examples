# Tensorflow deployment test

KServe under the hood is using Tensorflow Serving for serving the model.

## Exporting the model

Run the `notebooks/tensorflow.ipynb` notebook to have the model exported.

## Start serving

Using docker you can start serving a tensorflow model using the following command:

```bash
docker run -it --rm \
    -p 8501:8501 \
    --name=tf_serving \
    --mount type=bind,source=$(pwd)/../../models/tensorflow,target=/models/my_model \
    -e MODEL_NAME=my_model \
    -t tensorflow/serving
```

## Test predictions

Run the test predictions script to test if your model working correctly with Tensorflow Serving:

```bash
python test_predictions.py 360950
```