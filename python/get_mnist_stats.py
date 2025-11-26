import gzip
import sys
import numpy as np
import glob
import os

def twoscomp_to_decimal(inarray, bits_in_word):
    inputs = []
    for bin_input in inarray:
        if bin_input[0] == "0":
            inputs.append(int(bin_input, 2))
        else:
            inputs.append(int(bin_input, 2) - (1 << bits_in_word))
    inputs = np.array(inputs)
    return inputs

def load_layer_output(version, input_idx, layer_idx, root_dir):
    filename = os.path.join(root_dir, "mult{}_{}in_layer{}_out.txt".format(version, input_idx, layer_idx))
    with open(filename, 'r') as f:
        lines = f.readlines()
    # Determine bits based on layer? 
    # Layer 0 and 1 are intermediate, Layer 2 is final (10 classes).
    # The testbench writes binary strings.
    # Assuming 8-bit for now as per previous code, but intermediate layers might be wider?
    # Let's check the file content length or assume 8 bit.
    # The previous code used 8 bits.
    return twoscomp_to_decimal(lines, 8)

test_y = None
with open("../data/t10k-labels-idx1-ubyte.gz", "rb") as f:
    data = f.read()
    test_y = np.frombuffer(gzip.decompress(data), dtype=np.uint8).copy()

test_y = test_y[8:]

SVERILOG_BATCH_COUNT = 100
ROOT_DIR = "../results/"
SVERILOG_FINAL_LAYER = 2
VERSION = sys.argv[1]

# Accuracy Calculation
acc = 0
for i in range(0, SVERILOG_BATCH_COUNT):
    predictions = load_layer_output(VERSION, i, SVERILOG_FINAL_LAYER, ROOT_DIR)
    if predictions.argmax() == test_y[i]:
        acc += 1

print("Acc: ", acc * 100 / SVERILOG_BATCH_COUNT)

# NMED Calculation
# We need exact results for NMED.
EXACT_VERSION = "exact"
LAYERS = [0, 1, 2]

print("\nNMED Calculation:")
for layer in LAYERS:
    total_error_sum = 0
    max_exact_sum = 0
    
    for i in range(0, SVERILOG_BATCH_COUNT):
        try:
            approx_out = load_layer_output(VERSION, i, layer, ROOT_DIR)
            exact_out = load_layer_output(EXACT_VERSION, i, layer, ROOT_DIR)
            
            # Error per element
            diff = approx_out - exact_out
            
            # E_MAC sum over the layer output
            # The formula says Sum(Approx - Exact).
            # But wait, the formula image says E_MAC = Sum(Approx - Exact).
            # And NMED = Mean(|E_MAC|) / Max(Sum(Exact)).
            # Is E_MAC calculated per inference (per input image)?
            # Yes, "For each layer... processed using the testbench".
            # The sums are over l, i, j (channels, width, height).
            # So for one input image, we sum the errors of all pixels in that layer output.
            
            e_mac = np.sum(diff)
            total_error_sum += abs(e_mac)
            
            exact_sum = np.sum(exact_out)
            if abs(exact_sum) > max_exact_sum:
                max_exact_sum = abs(exact_sum)
                
        except FileNotFoundError:
            # print(f"Warning: Missing file for input {i} layer {layer}")
            continue

    if max_exact_sum > 0:
        nmed = (total_error_sum / SVERILOG_BATCH_COUNT) / max_exact_sum
        print(f"Layer {layer} NMED: {nmed:.6f}")
    else:
        print(f"Layer {layer} NMED: Undefined (Max Exact Sum is 0)")

