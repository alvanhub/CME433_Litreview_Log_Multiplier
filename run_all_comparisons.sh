#!/bin/bash

# Default multipliers to run if none provided
DEFAULT_MULTIPLIERS=("exact" "base_log" "dr_alm" "improved")

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

# Function to run simulation and capture stats
run_and_capture() {
    local mult_type=$1
    local mult_name=""
    local mult_version=""
    local mult_module=""

    # Map type to name/version/module
    case $mult_type in
        "exact")
            mult_name="Exact Multiplier"
            mult_version="exact"
            mult_module="dc_exact_16bit"
            ;;
        "base_log")
            mult_name="Base Log Mult"
            mult_version="base_log"
            mult_module="base_log_mult"
            ;;
        "dr_alm")
            mult_name="DR ALM"
            mult_version="dr_alm_core_16bit7trunc"
            mult_module="dr_alm_core_16bit7trunc"
            ;;
        "improved")
            mult_name="Improved DR ALM"
            mult_version="improved"
            mult_module="improved_dr_alm_16"
            ;;
        *)
            # Custom multiplier
            mult_name="$mult_type"
            mult_version="$mult_type"
            # For custom types, we assume the module name is the same as the type
            # or handled by switch_mult.sh logic we just added
            mult_module="$mult_type"
            ;;
    esac

    echo ""
    echo "------------------------------------------------------------"
    echo "Processing: $mult_name ($mult_type)"
    echo "------------------------------------------------------------"

    # 1. Switch Multiplier
    # echo ">>> Switching to $mult_name..."
    # cd src && bash switch_mult.sh "$mult_type" && cd .. || { echo "Failed to switch multiplier"; exit 1; }

    # 2. Run Simulation
    # echo ">>> Running simulation..."
    # cd sim
    # if [ "$mult_type" == "exact" ]; then
    #     # Check if exact results exist
    #     if [ ! -f "../results/multexact_0in_layer2_out.txt" ]; then
    #          csh -c "source ./gen_exact_results.sh" > /dev/null 2>&1
    #     else
    #          echo "    Exact results already exist, skipping simulation."
    #     fi
    # else
    #      csh -c "source ./run_tb.sh $mult_version" > /dev/null 2>&1
    # fi
    # cd ..

    # # 3. Calculate Stats (Accuracy & Layer NMED)
    # echo ">>> Calculating Accuracy and Layer NMED..."
    # cd python
    # local stats_output=$(python3 get_mnist_stats.py "$mult_version" 2>&1)
    # cd ..
    
    # # Parse Accuracy
    # local acc=$(echo "$stats_output" | grep "Acc:" | awk '{print $2}')
    # ACCURACY[$mult_type]=$acc
    
    # # Parse Layer NMEDs
    # local nmed0=$(echo "$stats_output" | grep "Layer 0 NMED:" | awk '{print $4}')
    # local nmed1=$(echo "$stats_output" | grep "Layer 1 NMED:" | awk '{print $4}')
    # local nmed2=$(echo "$stats_output" | grep "Layer 2 NMED:" | awk '{print $4}')
    # NMED_L0[$mult_type]=$nmed0
    # NMED_L1[$mult_type]=$nmed1
    # NMED_L2[$mult_type]=$nmed2

    # echo "    Accuracy: $acc"
    # echo "    Layer 0 NMED: $nmed0"
    # echo "    Layer 1 NMED: $nmed1"
    # echo "    Layer 2 NMED: $nmed2"

    # # 4. Calculate All-Input NMED
    # echo ">>> Calculating All-Input NMED..."
    # cd python
    # local nmed_all="N/A"
    
    # if [ "$mult_type" == "exact" ]; then
    #     nmed_all="0.000000"
    # elif [ "$mult_type" == "base_log" ]; then
    #      nmed_all=$(python3 -c "import sys; sys.path.insert(0, '.'); from check_mult_nmed import calculate_nmed_all; calculate_nmed_all()" 2>/dev/null | grep "NMED" | awk '{print $NF}')
    # elif [ "$mult_type" == "dr_alm" ]; then
    #      nmed_all=$(python3 check_mult_nmed.py 2>/dev/null | grep "NMED" | awk '{print $NF}')
    # elif [ "$mult_type" == "improved" ]; then
    #      nmed_all=$(python3 check_improved_nmed.py 2>/dev/null | grep "NMED" | awk '{print $NF}')
    # else
    #     # For custom multipliers, we don't have a python model ready
    #     nmed_all="N/A"
    # fi
    # cd ..
    # NMED_ALL[$mult_type]=$nmed_all
    # echo "    All-Input NMED: $nmed_all"

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
        
        AREA[$mult_type]=$area
        POWER[$mult_type]=$power
        DELAY[$mult_type]=$delay
        
        echo "    Area: $area"
        echo "    Power: $power"
        echo "    Delay: $delay"
    else
        echo "    Synthesis failed or files not found."
        AREA[$mult_type]="N/A"
        POWER[$mult_type]="N/A"
        DELAY[$mult_type]="N/A"
    fi
    cd ..
}

# Main Loop
for mult in "${MULTIPLIERS_TO_RUN[@]}"; do
    run_and_capture "$mult"
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
echo "===================================================================================================="
echo "                                    HARDWARE METRICS SUMMARY                                        "
echo "===================================================================================================="
echo ""
printf "%-20s %-15s %-15s %-15s %-15s\n" "Multiplier" "Accuracy" "Area (μm²)" "Power (mW)" "Delay (ns)"
printf "%-20s %-15s %-15s %-15s %-15s\n" "--------------------" "---------------" "---------------" "---------------" "---------------"

for mult in "${MULTIPLIERS_TO_RUN[@]}"; do
    printf "%-20s %-15s %-15s %-15s %-15s\n" "$mult" "${ACCURACY[$mult]}" "${AREA[$mult]}" "${POWER[$mult]}" "${DELAY[$mult]}"
done
echo ""