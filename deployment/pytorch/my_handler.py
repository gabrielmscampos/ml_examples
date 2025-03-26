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
        model_dir = properties.get("model_dir")
        model_path = f"{model_dir}/state_dict.pth"

        # Load model
        state_dict = torch.load(model_path, weights_only=True)
        self.model = InferenceAutoencoder(input_shape=(51,), l2_lambda=1e-4)
        self.model.load_state_dict(state_dict)
        self.model.eval()

    def preprocess(self, data):
        """Convert input data to tensor"""
        input_data = data[0].get("data") or data[0].get("body")
        input_data = torch.tensor(input_data.get("instances"), dtype=torch.float32)
        return input_data

    def inference(self, data):
        """Perform inference and return output"""
        with torch.no_grad():
            reconstructed, avg_mse = self.model(data)
        return reconstructed.numpy().tolist(), avg_mse.numpy().tolist()

    def postprocess(self, data):
        """Convert output to JSON format"""
        # We have to return the same length as the input:
        # If our input is: [[1,2,3], [1,2,3], ...]
        # Our output has to be [list|str|int|float, list|str|int|float, ...]
        # This way, the webser will but the payload directly on the response body
        reconstructed, avg_mse = data
        payload = []
        for idx in range(len(avg_mse)):
            payload.append({"output_0": reconstructed[idx], "output_1": avg_mse[idx]})
        return [payload]
