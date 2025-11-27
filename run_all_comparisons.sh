#!/bin/bash

# Default multipliers to run if none provided
DEFAULT_MULTIPLIERS=("exact" "base_log_mult" "dr_alm_core" "improved_dr_alm_16_approx_lod" "mitchell_log_mult_core")

# Check for arguments
if [ $# -eq 0 ]; then
    MULTIPLIERS_TO_RUN=("${DEFAULT_MULTIPLIERS[@]}")
else
    MULTIPLIERS_TO_RUN=("$@")
fi

echo "========================================"
echo "Running Comparisons for: ${MULTIPLIERS_TO_RUN[*]}"
echo "========================================"

# Associative arrays to store results
declare -A ACCURACY
declare -A NMED_L0
declare -A NMED_L1
declare -A NMED_L2
declare -A NMED_ALL
declare -A AREA
declare -A POWER
declare -A DELAY

all_result_mults=("exact" "base_log_mult")

# Function to run simulation and capture stats
run_and_capture() {
    local mult_type=$1
    local mult_module=$1
    local keep_width=$2
    local saved_keep_width=7
    local should_replace_keep_width=true
    local data_index=$mult_type

    # change mult_version for exact
    if [ "$mult_type" == "exact" ]; then
        mult_module="exact_16bit_mult"
    fi

    # Don't replace KEEP_WIDTH for exact multiplier and base_log_mult
    if [ "$mult_type" == "exact" ] || [ "$mult_type" == "base_log_mult" ]; then
        should_replace_keep_width=false
    fi

    # Find KEEP_WIDTH parameter value in source file and replace its value in the
    # source file to keep_width so that the dc_compiler and simulation use the same parameter
    if [ "$should_replace_keep_width" = true ]; then
        saved_keep_width=$(grep -oP 'parameter KEEP_WIDTH = \K[0-9]+' ./src/${mult_module}.sv)
        sed -i "s/parameter KEEP_WIDTH = [0-9]\+/parameter KEEP_WIDTH = $keep_width/" ./src/${mult_module}.sv
        echo "    Changed KEEP_WIDTH from $saved_keep_width to $keep_width in ./src/${mult_module}.sv"
        data_index=${mult_type}_$keep_width
        all_result_mults+=("$data_index")
    fi

    echo ""
    echo "------------------------------------------------------------"
    echo "Processing: ($mult_type), save to index $data_index"
    echo "------------------------------------------------------------"

    # 5. Run Synthesis & Capture Hardware Stats
    echo ">>> Running Synthesis..."
    cd design_compiler
    csh -c "source run_dc_analysis.csh $mult_module ../src/" > /dev/null 2>&1
    
    # # Capture results
    local area_file="dc_files/area_0.2_${mult_module}.txt"
    local power_file="dc_files/power_0.2_${mult_module}_TR0.01.txt"
    local timing_file="dc_files/timing_0.2_${mult_module}.txt"

    if [ -f "$area_file" ]; then
        local area=$(grep "Total cell area" "$area_file" | awk '{print $4}')
        # Power file format: Total ... ... ... ... ... ... 0.1361 mW
        # We want the 8th field (0.1361)
        local power=$(grep "^Total " "$power_file" | awk '{print $8}' | xargs)
        local delay=$(tail -n 20 "$timing_file" | grep "data arrival time" | awk '{print $4}')
        
        AREA[$data_index]=$area
        POWER[$data_index]=$power
        DELAY[$data_index]=$delay
        
        echo "    Area: $area"
        echo "    Power: $power"
        echo "    Delay: $delay"
    else
        echo "    Synthesis failed or files not found."
        AREA[$data_index]="N/A"
        POWER[$data_index]="N/A"
        DELAY[$data_index]="N/A"
    fi
    cd ..

    cd sim
    /bin/csh ./run_tb.sh $mult_type 2>&1 # | tee sim_output.txt 

    # Flag errors
    # local error_count=$(grep "Errors:" sim_output.txt | awk '{print $2}')
    # if [ "$error_count" -gt 0 ]; then
    #     echo "    Simulation reported $error_count errors!"
    # fi
    # extract stats
    cd ../python
    local stats_output=$(python3 get_mnist_stats.py $mult_type 2>&1)

    echo "    Stats Output:"
    echo "$stats_output"
    
    ACCURACY[$data_index]=$(echo "$stats_output" | grep "Final Classification Accuracy" | grep -oP '\d+\.\d+' | head -1)
    NMED_L0[$data_index]=$(echo "$stats_output" | grep -E "^0\s+\|" | awk -F'|' '{print $4}' | xargs)
    NMED_L1[$data_index]=$(echo "$stats_output" | grep -E "^1\s+\|" | awk -F'|' '{print $4}' | xargs)
    NMED_L2[$data_index]=$(echo "$stats_output" | grep -E "^2\s+\|" | awk -F'|' '{print $4}' | xargs)

    cd ..
    # Restore original KEEP_WIDTH value in source file
    if [ "$should_replace_keep_width" = true ]; then
        sed -i "s/parameter KEEP_WIDTH = $keep_width/parameter KEEP_WIDTH = $saved_keep_width/" ./src/${mult_module}.sv
    fi
}

# Main Loop
start_keep_width=7
end_keep_width=5
for mult in "${MULTIPLIERS_TO_RUN[@]}"; do
    if [ "$mult" == "exact" ] || [ "$mult" == "base_log_mult" ]; then
        run_and_capture "$mult" 0
    else
        for (( keep_width=$start_keep_width; keep_width>=$end_keep_width; keep_width-- )); do
            run_and_capture "$mult" $keep_width
        done
    fi
done

# Final Tables
# echo ""
# echo "===================================================================================================="
# echo "                                      FINAL RESULTS SUMMARY                                         "
# echo "===================================================================================================="
# echo ""
# printf "%-20s %-15s %-15s %-15s %-15s %-15s\n" "Multiplier" "Accuracy" "All-Input NMED" "Layer 0 NMED" "Layer 1 NMED" "Layer 2 NMED"
# printf "%-20s %-15s %-15s %-15s %-15s %-15s\n" "--------------------" "---------------" "---------------" "---------------" "---------------" "---------------"

# for mult in "${MULTIPLIERS_TO_RUN[@]}"; do
#     printf "%-20s %-15s %-15s %-15s %-15s %-15s\n" "$mult" "${ACCURACY[$mult]}" "${NMED_ALL[$mult]}" "${NMED_L0[$mult]}" "${NMED_L1[$mult]}" "${NMED_L2[$mult]}"
# done

echo ""
echo "=============================================================================================================================================="
echo "                                                    HARDWARE METRICS SUMMARY                                                                  "
echo "=============================================================================================================================================="
echo ""
printf "%-35s %-12s %-12s %-12s %-12s %-12s %-12s %-12s\n" "Multiplier" "Accuracy (%)" "L0 NMED (%)" "L1 NMED (%)" "L2 NMED (%)" "Area (μm²)" "Power (mW)" "Delay (ns)"
printf "%-35s %-12s %-12s %-12s %-12s %-12s %-12s %-12s\n" "-----------------------------------" "------------" "------------" "------------" "------------" "------------" "------------" "------------"

for mult in "${all_result_mults[@]}"; do
    printf "%-35s %-12s %-12s %-12s %-12s %-12s %-12s %-12s\n" "$mult" "${ACCURACY[$mult]}" "${NMED_L0[$mult]}" "${NMED_L1[$mult]}" "${NMED_L2[$mult]}" "${AREA[$mult]}" "${POWER[$mult]}" "${DELAY[$mult]}"
done
echo ""