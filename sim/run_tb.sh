source ./compile_designs.sh

vopt -work work tb_fullmnist -o tb_fullmnist_$1_opt

vsim -c "+V=$1" tb_fullmnist_$1_opt -do "run -all"
