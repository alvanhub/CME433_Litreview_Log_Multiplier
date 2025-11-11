# analyze -library work -format sverilog -autoread -recursive ${src_dir}
elaborate $design
create_clock -period $clk_period -name clock
set_max_area 0
compile_ultra
report_timing > ${root_dir}/timing_${clk_period}_${mult_name}.txt
report_area -hierarchy > ${root_dir}/area_${clk_period}_${mult_name}.txt
set_switching_activity [all_inputs] -static_probability 0.2 -toggle_rate $toggle_rate -base_clock clock
report_power > ${root_dir}/power_${clk_period}_${mult_name}_TR${toggle_rate}.txt
exit
