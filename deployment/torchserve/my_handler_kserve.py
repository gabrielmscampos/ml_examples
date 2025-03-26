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
        """
        Convert input data to tensor

        Since we are running torchserve behind KServe, differently from `my_handle.py`,
        the KServeEnvelope (https://pytorch.org/serve/_modules/ts/torch_handler/request_envelope/kserve.html#KServeEnvelope)
        automatically parse the inputs from the "instance" keys and forward it
        to this function.
        """
        input_data = torch.tensor(data, dtype=torch.float32)
        return input_data

    def inference(self, data):
        """Perform inference and return output"""
        with torch.no_grad():
            reconstructed, avg_mse = self.model(data)
        return reconstructed.numpy().tolist(), avg_mse.numpy().tolist()

    def postprocess(self, data):
        """
        Convert output to JSON format

        Since we are running torchserve behind KServe, differently from `my_handle.py`,
        the KServeEnvelope (https://pytorch.org/serve/_modules/ts/torch_handler/request_envelope/kserve.html#KServeEnvelope)
        do not automatically batch the outputs like JSONEnvelope. So, we don't need to return
        a list.
        """
        reconstructed, avg_mse = data
        payload = []
        for idx in range(len(avg_mse)):
            payload.append({"output_0": reconstructed[idx], "output_1": avg_mse[idx]})
        return payload
