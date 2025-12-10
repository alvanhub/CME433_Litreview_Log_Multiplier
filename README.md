# Literature Review TB for CME 433 Group 4
This git repository runs the testbench for Group 4's Literature review. It is a modified version of the original repository [CME433_TestBench_Fall25](https://github.com/UofS-KoLab/CME433_TestBench_Fall25).

# Running the Full Testbench
To run the full testbench, including the functional verifcation, hardware analysis and nmist network evaluation, a script is provided called `run_all_comparisons.sh`. 
To run the script, use the following command:
```bash
./run_all_comparisons.sh
```
This script will run the testbench for all implemented multipliers in the following list:
- exact
- base_log_mult
- dr_alm_core
- dr_alm_round
- dr_alm_round_and_est
- mitchell_log_mult_core

Take a look at the [run_all_comparisons.sh#L123-L124](run_all_comparisons.sh#L123-L124) to modify the range of `keep_widths` that are tested.

You will likely not want to run all the multipliers at once (as this will take a long time). Instead you can specify the names of the multipliers you want to run by passing them as arguments to the script. For example, to run the testbench for the exact and base_log_mult multipliers, use the following command:
```bash
./run_all_comparisons.sh exact base_log_mult
```

You may also want to shorten the range of `keep_widths` that are tested by modifying the necessary lines in the run_all_comparisons.sh script.

To run seperate sections of the testbench manually, you may still use the original instructions provided in the [CME433_TestBench_Fall25](https://github.com/UofS-KoLab/CME433_TestBench_Fall25) repository.

Keep in mind that you still need to manually change the `last_layer_mode` in the [tb_fullmnist.sv](testbench/tb_fullmnist.sv) file to toggle between running the approximate multipliers in all the layers or only the last layer.
