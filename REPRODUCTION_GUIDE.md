# Reproduction Guide - Approximate Logarithmic Multipliers

This guide shows researchers how to reproduce all results from RESULTS_SUMMARY.md.

## System Requirements

- **Simulator**: ModelSim/QuestaSim 2020.1+
- **Synthesis**: Synopsys Design Compiler 2020.09+ (for hardware metrics)
- **Technology**: TSMC 65nm library
- **Python**: Python 3.x with NumPy
- **Shell**: csh/tcsh

## Quick Start - Run All Comparisons

```bash
# Ensure you're in csh shell
csh

# Run complete comparison (takes ~5 minutes)
./run_all_comparisons.sh
```

This tests all four multipliers (Exact, Base Log, DR ALM, Improved DR ALM) and generates:
- Accuracy for each design
- NMED for all layers  
- Hardware metrics (Area, Power, Delay)

---

## Multiplier Configurations

### Truncation Settings (M_WIDTH Parameter)

| Multiplier | M_WIDTH | Bits Kept | Bits Truncated | Compensation |
|------------|---------|-----------|----------------|--------------|
| Base Log | N/A (7-bit) | 7 | 0 | None |
| DR ALM | **5** | 5 MSBs | 2 LSBs | None |
| Improved DR ALM | **5** | 5 MSBs | 2 LSBs | **Magnitude-aware** |

**M_WIDTH=5** means:
- Mantissa is 7 bits total (bits 6:0)
- Keep bits [6:2] (5 bits)
- Truncate bits [1:0] (2 bits)
- Reduces mantissa adder from 7-bit to 5-bit

---

## Step-by-Step Reproduction

### 1. Verify Baseline (Exact Multiplier)

```bash
cd sim
csh -c "source ./gen_exact_results.sh"
cd ../python
python3 get_mnist_stats.py exact
```

**Expected Output**:
```
Acc: 96.0

NMED Calculation:
Layer 0 NMED: 0.000000
Layer 1 NMED: 0.000000
Layer 2 NMED: 0.000000
```

### 2. Test Base Logarithmic Multiplier

```bash
# Switch to base log multiplier
cd ../src
bash switch_mult.sh base_log
cd ..

# Run simulation
cd sim
csh -c "source ./run_tb.sh base_log"
cd ../python
python3 get_mnist_stats.py base_log
```

**Expected Output**:
```
Acc: 93.0

NMED Calculation:
Layer 0 NMED: 0.002534
Layer 1 NMED: 0.010314
Layer 2 NMED: 0.153702
```

### 3. Test DR ALM (M_WIDTH=5)

```bash
# Switch to DR ALM
cd ../src
bash switch_mult.sh dr_alm
cd ..

# Run simulation
cd sim
csh -c "source ./run_tb.sh dr_alm"
cd ../python
python3 get_mnist_stats.py dr_alm
```

**Expected Output**:
```
Acc: 93.0

NMED Calculation:
Layer 0 NMED: 0.002003
Layer 1 NMED: 0.007970
Layer 2 NMED: 0.121207
```

### 4. Test Improved DR ALM (M_WIDTH=5 + Compensation)

```bash
# Switch to improved DR ALM
cd ../src
bash switch_mult.sh improved
cd ..

# Run simulation
cd sim
csh -c "source ./run_tb.sh improved"
cd ../python
python3 get_mnist_stats.py improved
```

**Expected Output**:
```
Acc: 95.0

NMED Calculation:
Layer 0 NMED: 0.005601
Layer 1 NMED: 0.002403
Layer 2 NMED: 0.060050
```

---

## Hardware Synthesis (Area/Power/Delay)

### Synthesize Each Multiplier

```bash
cd design_compiler

# Exact multiplier
csh -c "source run_dc_analysis.csh exact_mult ../src/"

# Base Log multiplier
csh -c "source run_dc_analysis.csh base_log_mult ../src/"

# DR ALM
csh -c "source run_dc_analysis.csh dr_alm ../src/"

# Improved DR ALM
csh -c "source run_dc_analysis.csh improved_dr_alm ../src/"
```

### Extract Results

```bash
cd dc_files

# Area
grep "Total cell area" area_0.2_exact_mult.txt
grep "Total cell area" area_0.2_base_log_mult.txt
grep "Total cell area" area_0.2_dr_alm.txt
grep "Total cell area" area_0.2_improved_dr_alm.txt

# Power
grep "^Total " power_0.2_exact_mult_TR0.01.txt | tail -1
grep "^Total " power_0.2_base_log_mult_TR0.01.txt | tail -1
grep "^Total " power_0.2_dr_alm_TR0.01.txt | tail -1
grep "^Total " power_0.2_improved_dr_alm_TR0.01.txt | tail -1

# Delay
tail -20 timing_0.2_exact_mult.txt | grep "data arrival time"
tail -20 timing_0.2_base_log_mult.txt | grep "data arrival time"
tail -20 timing_0.2_dr_alm.txt | grep "data arrival time"
tail -20 timing_0.2_improved_dr_alm.txt | grep "data arrival time"
```

**Expected Results**:

| Multiplier | Area (μm²) | Power (mW) | Delay (ns) |
|------------|------------|------------|------------|
| Exact | 476.28 | 0.096 | 0.84 |
| Base Log | 622.80 | 0.13 | 1.30 |
| DR ALM | 593.64 | 0.13 | 1.16 |
| Improved | 613.44 | 0.136 | 1.17 |

---

## Understanding NMED Calculations

### NMED Formula (from research paper)

```
E_MAC = Σ(Approx(i,j) - Exact(i,j))
NMED = Mean(|E_MAC|) / MAX(Σ|Exact(i,j)|)
```

### Our Implementation (`python/get_mnist_stats.py`)

```python
for layer in [0, 1, 2]:
    for input_image in range(100):
        approx_out = load_layer_output(version, i, layer)
        exact_out = load_layer_output("exact", i, layer)
        
        e_mac = np.sum(approx_out - exact_out)
        total_error += abs(e_mac)
        
        exact_sum = np.sum(exact_out)
        max_exact = max(max_exact, abs(exact_sum))
    
    nmed = (total_error / 100) / max_exact
```

### NMED Interpretation

- **Layer 0**: First hidden layer (256 neurons)
- **Layer 1**: Second hidden layer (128 neurons)
- **Layer 2**: Output layer (10 classes) - **Most critical**
- Lower NMED on Layer 2 → Better final accuracy

---

## Novel Truncation Logic (Improved DR ALM)

### What Makes It "Novel"?

The project requires "novel truncation logic circuit instead of simply using the value '1'".

**Our Innovation**: **Magnitude-Aware Adaptive Compensation**

```systemverilog
// Capture truncated bits
assign trunc_a = frac_a & ((1 << (7-M_WIDTH)) - 1);
assign trunc_b = frac_b & ((1 << (7-M_WIDTH)) - 1);

// Novel compensation logic
always_comb begin
    // Only compensate for large magnitudes (k >= 3)
    if ((k_a >= 3) && (k_b >= 3)) begin
        sum_trunc = trunc_a + trunc_b;
        
        // Use 75% threshold (not 50% or 100%)
        if (sum_trunc >= 0.75 * max_value)
            compensation = 1;
        else
            compensation = 0;
    end else begin
        compensation = 0; // No compensation for small values
    end
end
```

**Novel Aspects**:
1. **Uses actual truncated bit values** (not constant "1")
2. **Magnitude-aware gating** (k_a >= 3 AND k_b >= 3)
3. **Conservative threshold** (75% not 50%)
4. **Prevents bias in small multiplications**

**Result**: 95% accuracy (vs 93% for simple truncation)

---

## Testbench Architecture

### Processing Element (PE) Structure

The testbench uses `mult16bvia8bit` which contains **FOUR** 8-bit multipliers:

```systemverilog
module mult16bvia8bit (
    input  logic signed [15:0] i_a,  // 16-bit input
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z   // 32-bit output
);
    // Split 16-bit into four 8-bit multiplications
    // mult[0]: i_a[6:0] × i_b[6:0]
    // mult[1]: i_a[6:0] × i_b[14:7]
    // mult[2]: i_a[14:7] × i_b[6:0]
    // mult[3]: i_a[14:7] × i_b[14:7]
    
    // Result: o_z = mult[0] + (mult[1]+mult[2])×2^7 + mult[3]×2^14
endmodule
```

**Note**: The project description mentions "nine 8-bit multipliers" which would be for a 3×3 matrix-vector PE. Our current implementation uses **four** multipliers for 16-bit×16-bit decomposition into 8-bit operations.

---

## Common Issues & Solutions

### Issue 1: "Module not found" errors
**Solution**: Run compilation first:
```bash
cd sim
source ./compile_designs.sh
```

### Issue 2: Wrong accuracy results
**Solution**: Ensure exact multiplier results exist:
```bash
cd sim
csh -c "source ./gen_exact_results.sh"
```

### Issue 3: Hardware metrics missing
**Solution**: Run synthesis for that specific module:
```bash
cd design_compiler
csh -c "source run_dc_analysis.csh [module_name] ../src/"
```

---

## File Structure

```
CME433_Litreview_Log_Multiplier/
├── src/                      # Source files
│   ├── exact_mult.sv        # Exact 8×8 multiplier
│   ├── base_log_mult.sv     # Base logarithmic multiplier
│   ├── dr_alm.sv            # DR ALM (M_WIDTH=5, no compensation)
│   ├── improved_dr_alm.sv   # Improved DR ALM (M_WIDTH=5 + compensation)
│   ├── mult16via8.sv        # 16-bit wrapper using 4× 8-bit multipliers
│   └── switch_mult.sh       # Script to switch multiplier types
├── sim/                      # Simulation scripts
│   ├── gen_exact_results.sh # Generate baseline
│   ├── run_tb.sh            # Run testbench
│   └── compile_designs.sh   # Compile all designs
├── python/                   # Analysis scripts
│   ├── get_mnist_stats.py   # Calculate accuracy & NMED
│   └── check_mult_nmed.py   # Calculate all-input NMED
├── design_compiler/          # Synthesis
│   └── run_dc_analysis.csh  # Synthesis script
├── results/                  # Simulation outputs
├── RESULTS_SUMMARY.md        # Complete results documentation
└── run_all_comparisons.sh    # Master comparison script
```

---

## Customization

### Change Truncation Width

Edit `src/dr_alm.sv` or `src/improved_dr_alm.sv`:
```systemverilog
parameter M_WIDTH = 5  // Change to 3, 4, 6, or 7
```

Then re-run simulation and synthesis.

### Modify Compensation Logic

Edit `src/improved_dr_alm.sv` lines 62-88 to implement different compensation strategies.

---

## Validation

To verify your reproduction matches our results:

1. **Accuracy**: Should match within ±1%
2. **NMED**: Should match within ±5% (minor synthesis variations acceptable)
3. **Area/Power/Delay**: Should match within ±10% (synthesis tool version dependent)

---

*Last Updated: November 25, 2025*
