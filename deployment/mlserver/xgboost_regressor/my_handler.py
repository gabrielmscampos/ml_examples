import numpy as np
import xgboost as xgb
from sklearn.preprocessing import MinMaxScaler
from mlserver import MLModel
from mlserver.utils import get_model_uri
from mlserver.types import InferenceRequest, InferenceResponse, ResponseOutput, RequestInput, RequestOutput


DTYPE_MAP = {
    np.bool_: "BOOL",
    np.uint8: "UINT8",
    np.uint16: "UINT16",
    np.uint32: "UINT32",
    np.uint64: "UINT64",
    np.int8: "INT8",
    np.int16: "INT16",
    np.int32: "INT32",
    np.int64: "INT64",
    np.float16: "FP16",
    np.float32: "FP32",
    np.float64: "FP64",
}
TENSOR_TYPE_MAP = {type_string: np_dtype for np_dtype, type_string in DTYPE_MAP.items()}


def datatype_to_dtype(tensor_type):
    """
    Convert a tensor datatype string compliant to OIP to a numpy dtype
    Docs: https://kserve.github.io/website/master/modelserving/data_plane/v2_protocol/#tensor-data-types_1
    """
    return TENSOR_TYPE_MAP[tensor_type]


def dtype_to_datatype(dtype):
    """
    Convert a numpy dtype to a tensor datatype string compliant to OIP
    Docs: https://kserve.github.io/website/master/modelserving/data_plane/v2_protocol/#tensor-data-types_1
    """
    return DTYPE_MAP.get(np.dtype(dtype).type, "UNKNOWN")


class MyModelHandler(MLModel):
    async def load(self):
        model_uri = await get_model_uri(self._settings)
        self.model_name = self._settings.name
        self.model_version = self._settings.version
        self.model = xgb.Booster(model_file=model_uri)

    async def preprocess(self, inputs: list[RequestInput]) -> np.ndarray:
        """Process data sent from HTTP request"""
        input_datatype = datatype_to_dtype(inputs[0].datatype)
        input_shape = tuple(inputs[0].shape)
        input_data = np.array(inputs[0].data, dtype=input_datatype)
        if input_data.shape != input_shape:
            input_data = input_data.flatten().reshape(input_shape)
        return MinMaxScaler().fit_transform(input_data)

    async def inference(self, preprocessed_data: np.ndarray) -> tuple[np.ndarray]:
        """Run inference"""
        dmatrix = xgb.DMatrix(preprocessed_data)
        reconstructed = self.model.predict(dmatrix)
        avg_mse: np.ndarray = np.mean((preprocessed_data - reconstructed)**2, axis=1)
        return reconstructed, avg_mse

    async def postprocess(self, outputs: list[RequestOutput] | None, results: tuple[np.ndarray]) -> list[ResponseOutput]:
        """Process results from model inference and make each output compliant with Open Inference Protocol"""
        if outputs is None:
            output_names = [f"output-{idx}" for idx in range(len(results))]
        else:
            output_names = [output.name for output in outputs]

        _outputs = []
        for idx, result in enumerate(results):
            _outputs.append(ResponseOutput(
                name=output_names[idx],
                shape=result.shape,
                datatype=dtype_to_datatype(result.dtype),
                data=result.flatten().tolist()
            ))

        return _outputs

    async def predict(self, request: InferenceRequest) -> InferenceResponse:
        """
        Main handler called on each inference HTTP request at /infer

        Variables are overwritten to free memory, since in this specific case
        data from older steps are not usable in later steps.

        The output is compliant with Open Inference Protocol.
        """
        data = await self.preprocess(request.inputs)  # pre-processed data
        data = await self.inference(data)  # model results
        data = await self.postprocess(request.outputs, data)  # post-processed outputs compliant to OIP
        return InferenceResponse(
            id=request.id,
            model_name=self.model_name,
            model_version=self.model_version,
            outputs=data
        )