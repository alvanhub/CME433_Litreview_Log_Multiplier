#!/bin/csh
source /CMC/scripts/mentor.questasim.2020.1_1.csh

/bin/csh ./compile_designs.sh $1

vopt -work work tb_fullmnist -o tb_fullmnist_$1_opt

vsim -c "+V=$1" tb_fullmnist_$1_opt -do "run -all"
