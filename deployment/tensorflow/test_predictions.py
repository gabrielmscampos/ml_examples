import argparse

import numpy as np
import requests
import matplotlib.pyplot as plt


def inference_over_http(data: np.array, url: str | None = None, headers: dict | None = None):
    if url is None:
        url = "http://localhost:8501/v1/models/my_model:predict"
    if headers is None:
        headers = {}

    headers["Content-Type"] = "application/json"
    body = {"instances": data.tolist()}
    response = requests.post(url, json=body, headers=headers)
    response.raise_for_status()
    return response.json()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process run number, optional URL, and optional headers.")
    parser.add_argument("-r", "--run_number", type=int, help="The run number (required integer argument).")
    parser.add_argument("-u", "--url", type=str, help="Optional URL.")
    parser.add_argument("-H", "--headers", type=str, nargs='*', help="Optional headers in key=value format.")
    args = parser.parse_args()
    
    if args.run_number < 0:
        quit("ERROR: The provided run number must be a non-negative integer.")
    if args.headers:
        args.headers = dict(header.split("=", 1) for header in args.headers)

    data_arr = np.load("../../data/data_unfiltered.npy")
    run_arr = np.load("../../data/runs_unfiltered.npy")
    unique_runs = np.unique(run_arr)

    if args.run_number not in unique_runs:
        quit(f"ERROR: The specified run number is not present in the sample data. Please, choose one of the following: {unique_runs.tolist()}")
    
    # Collect the data to send to the model
    target_data = data_arr[run_arr == args.run_number]

    # Do the inference
    predictions = inference_over_http(target_data, args.url, args.headers)

    # Parse the output predictions
    reconstructed_data = []
    avg_mse = []
    for pred in predictions["predictions"]:
        reconstructed_data.append(pred["output_0"])
        avg_mse.append(pred["output_1"])

    # Plot
    avg_mse = np.array(avg_mse)
    plt.figure(figsize=(15, 5))
    plt.plot(range(avg_mse.shape[0]), avg_mse, label=f"MSE {args.run_number}")
    plt.legend()
    plt.show()
    plt.close()