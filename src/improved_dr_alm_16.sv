module improved_dr_alm_16 #(
    parameter M_WIDTH = 10     // number of kept mantissa bits (<= 15)
) (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);

  // ============================================================================
  // Sign and Absolute Value
  // ============================================================================
  logic sign_a, sign_b, sign_z;
  logic [15:0] abs_a, abs_b;

  assign sign_a = i_a[15];
  assign sign_b = i_b[15];
  assign sign_z = sign_a ^ sign_b;

  assign abs_a = sign_a ? -i_a : i_a;
  assign abs_b = sign_b ? -i_b : i_b;

  // ============================================================================
  // Leading One Detector (log2 characteristic)
  // ============================================================================
  function automatic [3:0] get_k(input logic [15:0] val);
    // Return type changed to [3:0] as it's sufficient for 0-15
    if (val[15]) return 15;
    if (val[14]) return 14;
    if (val[13]) return 13;
    if (val[12]) return 12;
    if (val[11]) return 11;
    if (val[10]) return 10;
    if (val[ 9]) return 9;
    if (val[ 8]) return 8;
    if (val[ 7]) return 7;
    if (val[ 6]) return 6;
    if (val[ 5]) return 5;
    if (val[ 4]) return 4;
    if (val[ 3]) return 3;
    if (val[ 2]) return 2;
    if (val[ 1]) return 1;
    return 0;
  endfunction

  logic [4:0] k_a, k_b; // [4:0] is fine to avoid overflow in sum_k
  assign k_a = get_k(abs_a);
  assign k_b = get_k(abs_b);

  // ============================================================================
  // Normalize Inputs & Extract Mantissa
  // ============================================================================
  logic [15:0] norm_a, norm_b;
  logic [14:0] frac_a, frac_b;

  assign norm_a = abs_a << (15 - k_a);
  assign norm_b = abs_b << (15 - k_b);
  assign frac_a = norm_a[14:0];
  assign frac_b = norm_b[14:0];

  // ============================================================================
  // Truncation - Following paper's approach (Alg 1 Step 2)
  // ============================================================================
  // Extract M_WIDTH-1 bits and append 1'b1 (implicit leading 1)
  // This matches: x_trunc <- {norm[(DWIDTH-2) -: (M_WIDTH-1)], 1'b1}
  logic [M_WIDTH-1:0] x_a_trunc, x_b_trunc;
  
  assign x_a_trunc = {frac_a[14 -: (M_WIDTH-1)], 1'b1};
  assign x_b_trunc = {frac_b[14 -: (M_WIDTH-1)], 1'b1};
  
  // Store remainder for adaptive compensation
  localparam REM_WIDTH = 15 - (M_WIDTH-1); // Remaining fraction bits
  logic [REM_WIDTH-1:0] trunc_a, trunc_b;
  assign trunc_a = frac_a[REM_WIDTH-1:0];
  assign trunc_b = frac_b[REM_WIDTH-1:0];

  // ============================================================================
  // Adaptive Compensation Logic (improved over paper's constant +1)
  // ============================================================================
  logic [M_WIDTH:0] compensation;
  logic [REM_WIDTH:0] sum_trunc;
  logic [REM_WIDTH:0] threshold;

  always_comb begin
    // Base compensation (paper uses constant +1)
    compensation = 1;
    
    // Adaptive: Only add extra compensation for large-magnitude multiplications
    // where truncation error is significant
    if (REM_WIDTH > 2 && (k_a >= 5) && (k_b >= 5)) begin
      sum_trunc = {1'b0, trunc_a} + {1'b0, trunc_b};      
      // Add +1 if truncated sum shows significant rounding error (>= 87.5%)
      // 87.5% = 7/8 = more conservative than 75%
      threshold = (7 * (1 << REM_WIDTH)) >> 3; // 87.5%
      if (sum_trunc >= threshold)
        compensation = compensation + 1;
    end
  end

  // ============================================================================
  // Add characteristics + truncated mantissas (Alg 1 Step 3 & 4)
  // ============================================================================
  logic [5:0] sum_k;
  logic [M_WIDTH:0] sum_x;

  assign sum_k = k_a + k_b;
  assign sum_x = x_a_trunc + x_b_trunc + compensation;

  // ============================================================================
  // Antilog (Alg 1 Step 5) - Following paper's approach
  // ============================================================================
  logic carry_x;
  logic [5:0] final_k;
  logic [M_WIDTH-1:0] final_x;
  logic [31:0] mantissa_reconst;
  logic [31:0] result_mag;

  assign carry_x = sum_x[M_WIDTH];
  assign final_k = sum_k + carry_x;
  assign final_x = sum_x[M_WIDTH-1:0];
  assign mantissa_reconst = {1'b1, final_x};

  always_comb begin
    if (abs_a == 0 || abs_b == 0) begin
      result_mag = 32'b0;
    end else begin
      // Shift mantissa to position final_k
      if (final_k >= M_WIDTH)
        result_mag = mantissa_reconst << (final_k - M_WIDTH);
      else
        result_mag = mantissa_reconst >> (M_WIDTH - final_k);
    end
  end

  // ============================================================================
  // Apply sign
  // ============================================================================
  assign o_z = sign_z ? -result_mag : result_mag;

endmodule