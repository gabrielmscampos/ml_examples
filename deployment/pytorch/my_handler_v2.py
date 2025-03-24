import logging

import torch
from my_model import InferenceAutoencoder
from ts.torch_handler.base_handler import BaseHandler

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


class InferenceAutoencoderHandler(BaseHandler):
    def __init__(self):
        super().__init__()
        self.model = None

    def initialize(self, context):
        """Load the model"""
        properties = context.system_properties
        manifest = context.manifest
        model_dir = properties.get("model_dir")
        model_path = f"{model_dir}/state_dict.pth"

        # Load model metadata
        self.model_name = manifest["model"]["modelName"]
        self.model_version = manifest["model"]["modelVersion"]
        self.request_ids = context.request_ids

        # Load model
        state_dict = torch.load(model_path, weights_only=True)
        self.model = InferenceAutoencoder(input_shape=(51,), l2_lambda=1e-4)
        self.model.load_state_dict(state_dict)
        self.model.eval()
        self.initialized = True

    def preprocess(self, data):
        """Convert input data to tensor"""
        return torch.tensor(data[0]['data'], dtype=torch.float32)

    def inference(self, data):
        """Perform inference and return output"""
        with torch.no_grad():
            reconstructed, avg_mse = self.model(data)
        return reconstructed.numpy(), avg_mse.numpy()

    def postprocess(self, data, request_id):
        """Convert output to JSON format following OIP standards"""
        reconstructed, avg_mse = data
        return [{
            "id": request_id,
            "model_name": self.model_name,
            "model_version": self.model_version,
            "outputs": [
                {
                    "name": "output-0",
                    "shape": reconstructed.shape,
                    "datatype": "FP32",
                    "data": reconstructed.tolist(),
                },
                {
                    "name": "output-1",
                    "shape": avg_mse.shape,
                    "datatype": "FP32",
                    "data": avg_mse.tolist(),
                },
            ]
        }]

    def handle(self, data, context):
        """
        Invoke by TorchServe for prediction request.
        Do pre-processing of data, prediction using model and postprocessing of prediciton output
        :param data: Input data for prediction
        :param context: Initial context contains model server system properties.
        :return: prediction output
        """
        if not self.initialized:
          self.initialized(context)
          
        model_input = self.preprocess(data)
        model_output = self.inference(model_input)
        return self.postprocess(model_output, context.get_request_id())