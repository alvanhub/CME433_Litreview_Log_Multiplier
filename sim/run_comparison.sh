#!/bin/csh
# Run comparison tests for all multiplier designs

source /CMC/scripts/mentor.questasim.2020.1_1.csh

echo "=========================================="
echo "Multiplier Design Comparison"
echo "=========================================="

# Compile all designs
echo ""
echo "Compiling designs..."
vlog ../src/*.sv
vlog ../testbench/*.sv

# Function to run MNIST test with specific design
echo ""
echo "=========================================="
echo "Testing Design 0: DR-ALM Baseline"
echo "=========================================="

# For baseline, we need to modify the define
# Using sed to change MULT_DESIGN value
sed -i 's/`define MULT_DESIGN [0-9]/`define MULT_DESIGN 0/' ../src/mult16via8.sv
vlog ../src/mult16via8.sv

vsim -c -do "run -all; quit" tb_fullmnist +MULT_VERSION=approx

cd ../python
python3 get_mnist_stats.py approx
cd ../sim

echo ""
echo "=========================================="
echo "Testing Design 1: Enhanced DR-ALM"
echo "=========================================="

sed -i 's/`define MULT_DESIGN [0-9]/`define MULT_DESIGN 1/' ../src/mult16via8.sv
vlog ../src/mult16via8.sv

vsim -c -do "run -all; quit" tb_fullmnist +MULT_VERSION=approx

cd ../python
python3 get_mnist_stats.py approx
cd ../sim

echo ""
echo "=========================================="
echo "Testing Design 2: Hybrid ALM"
echo "=========================================="

sed -i 's/`define MULT_DESIGN [0-9]/`define MULT_DESIGN 2/' ../src/mult16via8.sv
vlog ../src/mult16via8.sv

vsim -c -do "run -all; quit" tb_fullmnist +MULT_VERSION=approx

cd ../python
python3 get_mnist_stats.py approx
cd ../sim

echo ""
echo "=========================================="
echo "Testing Design 3: Iterative ALM"
echo "=========================================="

sed -i 's/`define MULT_DESIGN [0-9]/`define MULT_DESIGN 3/' ../src/mult16via8.sv
vlog ../src/mult16via8.sv

vsim -c -do "run -all; quit" tb_fullmnist +MULT_VERSION=approx

cd ../python
python3 get_mnist_stats.py approx
cd ../sim

echo ""
echo "=========================================="
echo "Comparison Complete"
echo "=========================================="
