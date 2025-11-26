#!/bin/csh

source /CMC/scripts/mentor.questasim.2020.1_1.csh


vlog ../src/*.sv

# Specify multiplier macro for the testbench
vlog -define $1 ../testbench/*.sv
# if ( "$1" == "exact" ) then
# else if ( "$1" == "LOG_MULT" ) then
#     vlog -define LOG_MULT ../testbench/*.sv
# else if ( "$1" == "DR_ALM_CORE" ) then
#     vlog -define DR_ALM_CORE ../testbench/*.sv
# else if ( "$1" == "DR_ALM_IMPROVED" ) then
#     vlog -define DR_ALM_IMPROVED ../testbench/*.sv
# endif
# vlog   ../testbench/*.sv