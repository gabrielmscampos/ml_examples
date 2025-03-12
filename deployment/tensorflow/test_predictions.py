import sys

import numpy as np
import requests
import matplotlib.pyplot as plt


def inference_over_http(data: np.array):
    url = "http://localhost:8501/v1/models/my_model:predict"
    body = {"instances": data.tolist()}
    response = requests.post(url, json=body)
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
    reconstructed_data = []
    avg_mse = []
    for pred in predictions["predictions"]:
        reconstructed_data.append(pred["output_0"])
        avg_mse.append(pred["output_1"])

    # Plot
    avg_mse = np.array(avg_mse)
    plt.figure(figsize=(15, 5))
    plt.plot(range(avg_mse.shape[0]), avg_mse, label=f"MSE {run_number}")
    plt.legend()
    plt.show()
    plt.close()