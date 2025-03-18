import sys

import numpy as np
import requests
import matplotlib.pyplot as plt


# This is only useful if testing the v1 endpoint
def inference_over_http_v1(data: np.array):
    url = "http://localhost:8080/v1/models/my_model:predict"
    headers = {"Content-Type": "application/json"}
    body = {"instances": data.tolist()}
    response = requests.post(url, headers=headers, json=body)
    response.raise_for_status()
    return response.json()


def inference_over_http(data: np.array):
    url = "http://localhost:8080/v2/models/my_model/infer"
    headers = {"Content-Type": "application/json"}
    body = {
        "inputs": [
            {
                "name": "input-0",
                "shape": data.shape,
                "datatype": "FP32",
                "data": data.tolist()
            }
        ]
    }
    response = requests.post(url, headers=headers, json=body)
    response.raise_for_status()
    return response.json()


if __name__ == "__main__":
    try:
        run_number = int(sys.argv[1])
    except IndexError:
        quit("ERROR: Specify a run number while calling this script.")
    except ValueError:
        quit("ERROR: The provided run number is invalid.")

    data_arr = np.load("../../data/data_unfiltered.npy")
    run_arr = np.load("../../data/runs_unfiltered.npy")
    unique_runs = np.unique(run_arr)

    if run_number not in unique_runs:
        quit(f"ERROR: The specified run number is not present in the sample data. Please, choose one of the following: {unique_runs.tolist()}")
    
    # Collect the data to send to the model
    target_data = data_arr[run_arr == run_number]

    # Do the inference
    predictions = inference_over_http(target_data)

    # Parse the output predictions
    outputs = predictions["outputs"]
    reconstructed_data = next(filter(lambda x: x["name"] == "output-0", outputs), None)["data"]
    avg_mse = next(filter(lambda x: x["name"] == "output-1", outputs), None)["data"]

    # Plot
    avg_mse = np.array(avg_mse)
    plt.figure(figsize=(15, 5))
    plt.plot(range(avg_mse.shape[0]), avg_mse, label=f"MSE {run_number}")
    plt.legend()
    plt.show()
    plt.close()