# Pytorch deployment test

KServe under the hood is using torchserve for serving the model.

## Exporting the model

Run the `notebooks/pytorch.ipynb` notebook to have the model exported.

## Package the model

The `my_handler` in the `torch-model-archiver` command refers to the custom inference handler you want to use for your model. A handler in TorchServe is a Python script that defines how the input data is processed, how the model inference is executed, and how the output is handled.

There are two main options for my_handler:

1. Built-in Handlers: TorchServe provides several built-in handlers for common tasks, such as image_classifier, text_classifier, transformer, etc. For example, if you're serving an image classification model, you can use the built-in image_classifier handler.

2. Custom Handlers: You can create a custom handler if you need specific preprocessing, postprocessing, or other logic that doesn't fit into the built-in handlers.

This repository already provides a `my_handle.py` file suited for the model created by `notebooks/pytorch.ipynb`.

```bash
mkdir -p model_store
torch-model-archiver \
    --version 1.0 \
    --model-name my_model \
    --serialized-file ../../models/torch/state_dict.pth \
    --model-file ./my_model.py \
    --handler ./my_handler.py \
    --export-path ./model_store \
    --force
```

The `--force` flag will automatically overwrite an existing `.mar` file in you `--export-path`.

## Start serving

### Docker

Using docker you can start serving a packaged torch model using the following command:

```bash
docker run -it --rm \
    -p 8080:8080 \
    -p 8081:8081 \
    --name torchserve \
    -v $(pwd)/model_store:/home/model-server/model-store \
    pytorch/torchserve \
    torchserve --start --model-store /home/model-server/model-store --models my_model=my_model.mar --disable-token-auth
```

Note: We are disabling the authentication token strategy for simplicity on this tutorial. On a real-world case, you have to enforce security through torch or another system. Read more about torch's token authorization api [here](https://github.com/pytorch/serve/blob/master/docs/token_authorization_api.md).

### Native

If you have torchserve installed (`pip install torchserve`), you can start serving the model using it directly:

```bash
torchserve --start --model-store ./model_store --models my_model=my_model.mar --foreground --disable-token-auth
```

Optionally you can remove the `--foreground` flag to run torchserve in the background. If you do, use `torchserve --stop` to stop the server.

## Test predictions

Run the test predictions script to test if your model working correctly with torchserver:

```bash
python test_predictions.py 360950
```