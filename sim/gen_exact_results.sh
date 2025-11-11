source ./compile_designs.sh

vopt -work work tb_fullmnist -o tb_fullmnist_exact_opt

vsim -c "+V=exact" tb_fullmnist_exact_opt -do "run -all"
