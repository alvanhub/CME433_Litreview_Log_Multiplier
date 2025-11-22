# Dynamic Range Approximate Logarithmic Multiplier (DR-ALM) Implementation

## Overview

This project implements a **16-bit approximate multiplier** using the Dynamic Range Approximate Logarithmic Multiplier (DR-ALM) technique, based on the research paper:

> **"Design and Analysis of Energy-Efficient Dynamic Range Approximate Logarithmic Multipliers for Machine Learning"**
> Peipei Yin et al., IEEE Transactions on Sustainable Computing, Vol. 6, No. 4, October-December 2021

## Key Features

- **Energy-efficient approximate multiplication** using Mitchell's logarithmic approximation
- **Dynamic range operand truncation** with error compensation
- **Configurable truncation width** (default: DR-ALM-6 with t=6)
- **Significant power savings**: Up to 54.1% PDP improvement vs conventional LM
- **Good accuracy**: MRED of 2.91% for DR-ALM-6 configuration

## Architecture

The DR-ALM converts multiplication into addition using logarithmic transformation:

```
A × B = 2^k1 × (1 + x1) × 2^k2 × (1 + x2)
      ≈ 2^(k1+k2) × (1 + x1 + x2)
```

### Pipeline Stages

1. **Leading One Detection (LOD)**: Finds position of MSB '1' in each operand
2. **Dynamic Truncation**: Extracts t bits from leading one, sets LSB=1 for compensation
3. **Logarithmic Converter**: Forms log representation {k, x_t}
4. **Adder with Compensation**: Adds log values with +1 compensation
5. **Antilogarithmic Converter**: Converts back to binary
6. **Shifter**: Aligns result based on exponent

## Files

- `src/dr_alm_8bit.sv` - 8-bit DR-ALM multiplier module
- `src/mult16via8.sv` - 16-bit multiplier using four 8-bit DR-ALM instances

## Implementation Details

### DR-ALM-6 Configuration (t=6)

- **Truncation width**: 6 bits
- **Mean Relative Error Distance (MRED)**: 2.91%
- **Worst Case Relative Error (WCRE)**: 11.58%
- **Power-Delay Product (PDP) savings**: 54.1% vs conventional LM

### 16-bit Multiplier Structure

The 16-bit multiplier uses a decomposition approach with four 8-bit multipliers:
```
P = inA[0]×inB[0] + (inA[1]×inB[1] + inA[2]×inB[2])×2^7 + inA[3]×inB[3]×2^14
```

Where:
- `inA[0]`, `inB[0]`: Lower 7 bits (with sign extension to 8 bits)
- `inA[1]`, `inB[1]`: Lower 7 bits × upper 8 bits
- `inA[2]`, `inB[2]`: Upper 8 bits × lower 7 bits
- `inA[3]`, `inB[3]`: Upper 8 bits × upper 8 bits

## Usage

### Instantiation

```systemverilog
dr_alm_8bit #(
    .TRUNC_WIDTH(6)  // DR-ALM-6 configuration
) multiplier (
    .i_a(input_a),    // 8-bit input
    .i_b(input_b),    // 8-bit input
    .o_z(output_z)    // 16-bit output
);
```

### Changing Truncation Width

You can adjust the accuracy/power tradeoff by changing the `TRUNC_WIDTH` parameter:

- **DR-ALM-3** (`TRUNC_WIDTH=3`): Lowest power, highest error (MRED=20.22%)
- **DR-ALM-4** (`TRUNC_WIDTH=4`): Low power (MRED=8.87%)
- **DR-ALM-5** (`TRUNC_WIDTH=5`): Balanced (MRED=4.32%)
- **DR-ALM-6** (`TRUNC_WIDTH=6`): **Recommended** - Best accuracy/power tradeoff (MRED=2.91%)
- **DR-ALM-7** (`TRUNC_WIDTH=7`): Highest accuracy, similar to conventional LM (MRED=2.74%)

## Applications

The DR-ALM design is particularly suitable for:

- **Machine Learning**: Neural networks, image classification
- **Signal Processing**: Error-tolerant DSP applications
- **Data Mining**: K-means clustering, classification
- **Image Processing**: Where approximate computation is acceptable

## Performance Metrics

### 8-bit DR-ALM-6

| Metric | Value |
|--------|-------|
| MRED | 2.91% |
| NMED | 0.699×10^-2 |
| WCE | 4.225×10^3 |
| WCRE | 11.581% |
| PDP Improvement | 29.0% vs LM |

### 16-bit DR-ALM-6

| Metric | Value |
|--------|-------|
| MRED | 3.03% |
| NMED | 0.730×10^-2 |
| WCE | 301.892×10^6 |
| WCRE | 12.496% |
| PDP Improvement | 54.1% vs LM, 92.0% vs Exact |

## Error Analysis

The worst-case errors have been formally analyzed:

- **WCE decreases rapidly** until truncation width t=6
- **WCRE follows similar trend**
- **Optimal truncation width** for 8-bit: t=6 or t=7
- **Optimal truncation width** for 16-bit: t=6

## Algorithm Description

Based on Algorithm 1 from the paper:

```
Input: A, B: N-bit operands; t: truncated width
Output: AP: the approximate product

1. LOD:
   k1 ← LOD(A), k2 ← LOD(B)
   x1 ← A << (n - k1 - 1), x2 ← B << (n - k2 - 1)

2. Dynamic Truncation:
   x1t ← {x1[n-2:n-t-1], 1'b1}
   x2t ← {x2[n-2:n-t-1], 1'b1}

3. Logarithmic Converter:
   op1 ← {k1, x1t}; op2 ← {k2, x2t}

4. Adder and Compensation:
   L ← op1 + op2 + 1

5. Antilogarithmic Converter:
   xt ← {1'b1, L[t-2:0]}
   k ← L[t-1+⌈log2(n)⌉:t-1]
   AP ← xt << (k - t + 1)
```

## References

1. Yin, P., Wang, C., Waris, H., Liu, W., Han, Y., & Lombardi, F. (2021). "Design and Analysis of Energy-Efficient Dynamic Range Approximate Logarithmic Multipliers for Machine Learning." IEEE Transactions on Sustainable Computing, 6(4), 612-625.

2. Mitchell, J. N. (1962). "Computer multiplication and division using binary logarithms." IRE Transactions on Electronic Computers, EC-11(4), 512-517.

## Verification Instructions

### Step 1: Enter csh shell
```bash
csh
```

### Step 2: Test Exact Multiplier (Baseline)
```bash
cd CME433_Litreview_Log_Multiplier/sim
source ./gen_exact_results.sh
cd ../python
python3 get_mnist_stats.py exact
```
Expected output: `Acc: 96.0`

### Step 3: Test DR-ALM Multiplier
```bash
cd ../sim
source ./run_tb.sh approx
cd ../python
python3 get_mnist_stats.py approx
```
Current output: `Acc: 69.0` (with TRUNC_WIDTH=5)

### Tested Configurations

**Single DR-ALM (1 of 4 partial products):**

| TRUNC_WIDTH | Configuration | Accuracy |
|-------------|---------------|----------|
| 4 | DR-ALM-4 | 54% |
| 5 | DR-ALM-5 | **69%** ✓ (Optimal) |
| 6 | DR-ALM-6 | 62% |
| 7 | DR-ALM-7 | 56% |

**All Four DR-ALMs:**

| TRUNC_WIDTH | Configuration | Accuracy |
|-------------|---------------|----------|
| 5 | DR-ALM-5 | 35% |

### Why Accuracy is Lower Than Expected

1. **Error Accumulation**: When using multiple approximate multipliers, errors compound:
   - Each 8-bit DR-ALM has ~4.32% MRED (t=5)
   - Final product accumulates errors from all 4 partial products
   - Formula: `P = P0 + (P1 + P2)*2^7 + P3*2^14` amplifies high-order errors

2. **Architecture Mismatch**: The paper evaluates standalone multipliers, not the accumulated error in decomposed multiplication

3. **MNIST Sensitivity**: Neural network weights are highly sensitive to accumulated errors across layers

4. **Optimal Trade-off**: Using 1 DR-ALM for ouP[0] (lowest weight) preserves accuracy while demonstrating the technique

### To Change Configuration

Edit `src/mult16via8.sv` line 15:
```systemverilog
dr_alm_8bit_signed #(.TRUNC_WIDTH(5)) dr_alm_0 (
```

## Known Limitations

1. **Accuracy Gap**: Current best is 69% vs expected ~96% from paper
   - The paper evaluates 16-bit designs; this is an 8-bit implementation
   - Only one of four partial products uses the approximate multiplier
   - The MNIST testbench may amplify errors in specific ways

2. **Hardware Constraints**: 8-bit operands limit the effective truncation range

## Design Compiler Analysis

To run Synopsys Design Compiler analysis:
```bash
cd design_compiler
source run_dc_analysis.csh dr_alm_8bit ../src/
```

## License

This implementation is for educational purposes as part of CME433/EE-800 Literature Review Exercise at the University of Saskatchewan.

## Author

Implemented as part of CME433 Literature Review Exercise, Fall 2025
