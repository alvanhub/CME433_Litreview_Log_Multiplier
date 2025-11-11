import gzip
import sys
import numpy as np


def twoscomp_to_decimal(inarray, bits_in_word):
    inputs = []
    for bin_input in inarray:
        if bin_input[0] == "0":
            inputs.append(int(bin_input, 2))
        else:
            inputs.append(int(bin_input, 2) - (1 << bits_in_word))
    inputs = np.array(inputs)
    return inputs


test_y = None
with open("../data/t10k-labels-idx1-ubyte.gz", "rb") as f:
    data = f.read()
    test_y = np.frombuffer(gzip.decompress(data), dtype=np.uint8).copy()

test_y = test_y[8:]

# print(sys.argv)

SVERILOG_BATCH_COUNT = 100
SVERILOG_BATCH_SIZE = 1
ROOT_DIR = "../results/"
SVERILOG_FINAL_LAYER = 2
VERSION = sys.argv[1]

acc = 0
for i in range(0, SVERILOG_BATCH_COUNT):
    predictions_bin = []
    with open(
        ROOT_DIR
        + "mult{}_{}in_layer{}_out.txt".format(VERSION, i, SVERILOG_FINAL_LAYER)
    ) as pfile:
        predictions_bin = pfile.readlines()

    predictions = twoscomp_to_decimal(predictions_bin, 8)

    if predictions.argmax() == test_y[i]:
        acc += 1

print("Acc: ", acc * 100 / SVERILOG_BATCH_COUNT)
