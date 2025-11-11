#!/bin/csh

source /CMC/scripts/synopsys.syn.2020.09-SP1.csh

dc_shell-t -f ./syn_genreports.tcl -x "set mult_name $1;analyze -library work -format sverilog -autoread -recursive {$2};set root_dir ./dc_files/;set clk_period 0.2;set design $1;set toggle_rate 0.01"
