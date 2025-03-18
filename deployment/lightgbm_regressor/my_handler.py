import joblib
import numpy as np
from sklearn.preprocessing import MinMaxScaler
from mlserver import MLModel
from mlserver.utils import get_model_uri
from mlserver.types import InferenceRequest, InferenceResponse, ResponseOutput


class MyModelHandler(MLModel):
    async def load(self):
        model_uri = await get_model_uri(self._settings)
        self.model = joblib.load(model_uri)

    async def predict(self, request: InferenceRequest) -> InferenceResponse:
        input_data = request.inputs[0].data
        input_data = MinMaxScaler().fit_transform(input_data)
        reconstructed = self.model.predict(input_data)
        mse: np.ndarray = np.mean((input_data - reconstructed)**2, axis=1)

        return InferenceResponse(
            id=request.id,
            model_name=self.name,
            model_version=self.version,
            outputs=[
                ResponseOutput(
                    name="output-0",
                    shape=reconstructed.shape,
                    datatype="FP32",
                    data=reconstructed.tolist()
                ),
                ResponseOutput(
                    name="output-1",
                    shape=mse.shape,
                    datatype="FP32",
                    data=mse.tolist()
                ),
            ]
        )