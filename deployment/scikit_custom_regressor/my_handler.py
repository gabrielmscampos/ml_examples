import joblib
import __main__
from my_model import Preprocessing, NMFRegressor
from mlserver import MLModel
from mlserver.utils import get_model_uri
from mlserver.types import InferenceRequest, InferenceResponse, ResponseOutput
import requests

# When joblib tries to load our model it will look in the module name the was dumped
# for custom objects needed by our model. Since our model was dumped from a jupyter notebook
# the default module named used is __main__.
# Our model is a scikit-learn Pipeline of Preprocessing -> NMFRegressor
# So we need both custom definitions during runtime in __main__.
setattr(__main__, "Preprocessing", Preprocessing)
setattr(__main__, "NMFRegressor", NMFRegressor)


class MyModelHandler(MLModel):
    async def load(self):
        model_uri = await get_model_uri(self._settings)
        self.model = joblib.load(model_uri)
        print(f"Model {self.name} loaded successfully.")

    async def predict(self, request: InferenceRequest) -> InferenceResponse:
        input_data = request.inputs[0].data
        reconstructed, mse = self.model.predict(input_data)
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