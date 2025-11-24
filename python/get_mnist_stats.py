import gzip
import sys
import numpy as np
import os


def twoscomp_to_decimal(inarray, bits_in_word):
    inputs = []
    for bin_input in inarray:
        clean_input = bin_input.strip() # Remove newlines
        if not clean_input: continue 
        
        if clean_input[0] == "0":
            inputs.append(int(clean_input, 2))
        else:
            inputs.append(int(clean_input, 2) - (1 << bits_in_word))
    inputs = np.array(inputs)
    return inputs

# ---------------- Configuration ----------------
SVERILOG_BATCH_COUNT = 100
ROOT_DIR = "../results/"
SVERILOG_FINAL_LAYER = 2

# The version you are testing (passed as argument, e.g., "approx")
VERSION = sys.argv[1] 

# The version to use as the "Golden" reference (e.g., "exact", "default")
# Ensure you have run the simulation with this version to generate reference files!
GOLDEN_VERSION = "exact" 
# -----------------------------------------------

# Load Labels
test_y = None
with open("../data/t10k-labels-idx1-ubyte.gz", "rb") as f:
    data = f.read()
    test_y = np.frombuffer(gzip.decompress(data), dtype=np.uint8).copy()
test_y = test_y[8:]

acc = 0
total_error_distance = 0
total_elements = 0

print(f"Calculating Accuracy for '{VERSION}' and NMED against '{GOLDEN_VERSION}'...")

for i in range(0, SVERILOG_BATCH_COUNT):
    # 1. Load Approximate Predictions
    approx_file = ROOT_DIR + "mult{}_{}in_layer{}_out.txt".format(VERSION, i, SVERILOG_FINAL_LAYER)
    with open(approx_file) as pfile:
        approx_bin = pfile.readlines()
    approx_preds = twoscomp_to_decimal(approx_bin, 8)

    # 2. Load Exact (Golden) Predictions for NMED
    exact_file = ROOT_DIR + "mult{}_{}in_layer{}_out.txt".format(GOLDEN_VERSION, i, SVERILOG_FINAL_LAYER)
    
    if os.path.exists(exact_file):
        with open(exact_file) as efile:
            exact_bin = efile.readlines()
        exact_preds = twoscomp_to_decimal(exact_bin, 8)
        
        # Calculate Error Distance (Absolute Difference)
        # ED = |Approx - Exact|
        error_dist = np.abs(approx_preds - exact_preds)
        
        # Accumulate for Mean Error Distance (MED)
        total_error_distance += np.sum(error_dist)
        total_elements += len(exact_preds)
    else:
        if i == 0: print(f"Warning: Exact file {exact_file} not found. NMED will be 0.")

    # 3. Calculate Accuracy (Classification Rate)
    # Using argmax to find the predicted digit (0-9)
    if approx_preds.argmax() == test_y[i]:
        acc += 1

# --- Final Metrics ---

# Accuracy
accuracy_percent = acc * 100 / SVERILOG_BATCH_COUNT

# Mean Error Distance (MED)
if total_elements > 0:
    med = total_error_distance / total_elements
else:
    med = 0

# Normalized Mean Error Distance (NMED / NED)
# As per Section 4.4 of the referenced paper, NED = MED / D.
# For 8-bit outputs, the maximum range D is 2^8 = 256.
normalization_factor = 2**8
nmed = med / normalization_factor

print("-" * 30)
print(f"Accuracy: {accuracy_percent:.2f}%")
print(f"MED:      {med:.4f}")
print(f"NMED:     {nmed:.6f} (or {nmed*100:.4f}%)")
print("-" * 30)
