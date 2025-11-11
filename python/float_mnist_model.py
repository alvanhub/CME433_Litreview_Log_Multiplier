import numpy as np

def matmul(input, weights, apply_relu):
    output = input.astype(np.float64).dot(weights.T)
    # print(output.min(), output.max())
    if apply_relu:
        output[output<0] = 0
    # print(output)
    return output
def softmax(vector):
	e = np.exp(vector)
	return e / e.sum()

test_set = np.load("../data/EE800data/floatmnist_labels.npy")

acc = 0
batch_count = 1000
batch_start = 0
for in_idx in range(batch_start, batch_start+batch_count):
    str_lines = None
    # with open("../../../data/mnist_ifloat/inf_{}.txt".format(in_idx), "r") as readfile:
    #     str_lines = readfile.readlines()
    # mnist_input = [float(str_float) for str_float in str_lines]
    
    mnist_input = list(np.load("../data/EE800data/mnist_ifloat/inf_{}.npy".format(in_idx)))
    mnist_inputs_np = np.array([mnist_input])

    layer_output = None
    for layer_idx in range(3): 
        layer_weights = np.load("../data/EE800data/mnist_wfloat/layer{}_fw.npy".format(layer_idx))
        # print(layer_weights.shape)
        # layer_weights = layers[layer_idx]
        # layer_weights_np = np.array(layer_weights)
        if not layer_idx:
            layer_height = int(layer_weights.shape[0]/len(mnist_input))
            layer_width = int(len(mnist_input))
            layer_weights_np = layer_weights.reshape((layer_height, layer_width))
            layer_output = matmul(mnist_inputs_np, layer_weights_np, True)
            # break
        else:
            layer_height = int(layer_weights.shape[0]/layer_output.shape[1])
            layer_width = layer_output.shape[1]
            layer_weights_np = layer_weights.reshape((layer_height, layer_width))
            if layer_idx == 2:
                layer_output = matmul(layer_output, layer_weights_np, False)
                layer_output = softmax(layer_output)
            else:
                layer_output = matmul(layer_output, layer_weights_np, True)
        # print(layer_output.shape)
    # break
    # print(layer_output.argmax())
    if layer_output.argmax() == test_set[in_idx]:
        acc += 1
print("Accuracy:", acc/batch_count)