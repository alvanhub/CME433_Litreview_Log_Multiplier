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
if len(sys.argv) > 1:
    VERSION = sys.argv[1]
else:
    VERSION = "approx" # Default fallback if no arg provided

# The version to use as the "Golden" reference
GOLDEN_VERSION = "exact" 
# -----------------------------------------------

# Load Labels (Only needed for final layer accuracy)
test_y = None
try:
    with open("../data/t10k-labels-idx1-ubyte.gz", "rb") as f:
        data = f.read()
        test_y = np.frombuffer(gzip.decompress(data), dtype=np.uint8).copy()
    test_y = test_y[8:]
except FileNotFoundError:
    print("Error: Label file '../data/t10k-labels-idx1-ubyte.gz' not found.")
    sys.exit(1)

# Initialize metrics storage
acc = 0
# Dictionary to store error stats per layer: { layer_idx: {'total_err': 0, 'count': 0} }
layer_stats = {l: {'total_err': 0, 'count': 0} for l in range(SVERILOG_FINAL_LAYER + 1)}

print(f"Calculating NMED for layers 0-{SVERILOG_FINAL_LAYER} and Accuracy for layer {SVERILOG_FINAL_LAYER}...")
print(f"Comparing '{VERSION}' against '{GOLDEN_VERSION}'")

for i in range(0, SVERILOG_BATCH_COUNT):
    
    # Iterate through each layer for the current batch
    for layer_idx in range(SVERILOG_FINAL_LAYER + 1):
        
        # 1. Load Approximate Predictions
        approx_file = ROOT_DIR + "mult{}_{}in_layer{}_out.txt".format(VERSION, i, layer_idx)
        
        # STRICT CHECK: Error out immediately if file is missing
        if not os.path.exists(approx_file):
            print(f"CRITICAL ERROR: Output file not found: {approx_file}")
            sys.exit(1)

        with open(approx_file) as pfile:
            approx_bin = pfile.readlines()
        approx_preds = twoscomp_to_decimal(approx_bin, 8)

        # 2. Load Exact (Golden) Predictions for NMED
        exact_file = ROOT_DIR + "mult{}_{}in_layer{}_out.txt".format(GOLDEN_VERSION, i, layer_idx)
        
        if not os.path.exists(exact_file):
             print(f"CRITICAL ERROR: Golden reference file not found: {exact_file}")
             sys.exit(1)

        with open(exact_file) as efile:
            exact_bin = efile.readlines()
        exact_preds = twoscomp_to_decimal(exact_bin, 8)
        
        # Ensure dimensions match before calculation
        min_len = min(len(approx_preds), len(exact_preds))
        approx_preds_c = approx_preds[:min_len]
        exact_preds_c = exact_preds[:min_len]

        # Calculate Error Distance (Absolute Difference)
        error_dist = np.abs(approx_preds_c - exact_preds_c)
        
        # Accumulate stats for this specific layer
        layer_stats[layer_idx]['total_err'] += np.sum(error_dist)
        layer_stats[layer_idx]['count'] += len(exact_preds_c)

        # 3. Calculate Accuracy (Only applicable to the final layer)
        if layer_idx == SVERILOG_FINAL_LAYER:
            # check bounds to avoid crash if output is shorter than expected
            if len(approx_preds) > 0:
                # Using argmax to find the predicted digit (0-9)
                if approx_preds.argmax() == test_y[i]:
                    acc += 1

# --- Final Metrics & Output ---

# Final Layer Accuracy
accuracy_percent = acc * 100 / SVERILOG_BATCH_COUNT

print("\n" + "=" * 65)
print(f" RESULTS SUMMARY (Version: {VERSION})")
print("=" * 65)
print(f"Final Classification Accuracy (Layer {SVERILOG_FINAL_LAYER}): {accuracy_percent:.2f}%")
print("-" * 65)
print(f"{'Layer':<10} | {'MED':<15} | {'NMED':<15} | {'NMED (%)':<15}")
print("-" * 65)

normalization_factor = 2**8 # For 8-bit outputs

for layer_idx in range(SVERILOG_FINAL_LAYER + 1):
    stats = layer_stats[layer_idx]
    
    if stats['count'] > 0:
        med = stats['total_err'] / stats['count']
    else:
        med = 0.0
        
    nmed = med / normalization_factor
    
    print(f"{layer_idx:<10} | {med:<15.4f} | {nmed:<15.6f} | {nmed*100:<15.4f}%")

print("-" * 65)